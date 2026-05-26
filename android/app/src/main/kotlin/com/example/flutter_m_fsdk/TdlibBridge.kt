package com.example.flutter_m_fsdk

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel
import org.drinkless.tdlib.JsonClient
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.thread

class TdlibBridge(private val context: Context) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = ConcurrentHashMap<String, CompletableFuture<JSONObject>>()
    private val sendWaiters = ConcurrentHashMap<String, CompletableFuture<JSONObject>>()
    private val completedSends = ConcurrentHashMap<String, JSONObject>()
    private val failedSends = ConcurrentHashMap<String, TdlibException>()
    private val downloads = ConcurrentHashMap<Int, DownloadWaiter>()
    private val transfers = ConcurrentHashMap<String, Transfer>()
    private val authorizationWaiters = CopyOnWriteArrayList<AuthorizationWaiter>()
    private val connectionWaiters = CopyOnWriteArrayList<ConnectionWaiter>()
    private val lastEmittedAtByTransferId = ConcurrentHashMap<String, Long>()
    private val lastEmittedFractionByTransferId = ConcurrentHashMap<String, Int>()
    private val lastEmittedStateByTransferId = ConcurrentHashMap<String, String>()
    private val terminalStates = setOf("completed", "failed", "cancelled")
    private val progressMinIntervalMs = 250L

    @Volatile private var eventSink: EventChannel.EventSink? = null
    @Volatile private var clientId: Int = 0
    @Volatile private var receiverStarted = false
    @Volatile private var config: Config? = null
    @Volatile private var activeScopeKey: String? = null
    @Volatile private var authorizationState: String = "authorizationStateClosed"
    @Volatile private var connectionState: String = "connectionStateWaitingForNetwork"
    @Volatile private var loadError: Throwable? = null
    @Volatile private var loaded = false
    private val configureLock = Any()

    init {
        try {
            System.loadLibrary("tdjsonjava")
            loaded = true
        } catch (error: Throwable) {
            loadError = error
            loaded = false
        }
    }

    fun isAvailable(): Boolean = loaded

    fun configure(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        if (!loaded) {
            return failed(TdlibException("tdlib_unavailable", "Official TDLib tdjsonjava artifact is not packaged for this ABI.", loadError?.message))
        }
        val apiId = intArg(args, "apiId")
            ?: return failed(TdlibException("tdlib_api_credentials_missing", "TELEGRAM_API_ID is required for local TDLib."))
        val apiHash = stringArg(args, "apiHash")
        if (apiHash.isNullOrBlank()) {
            return failed(TdlibException("tdlib_api_credentials_missing", "TELEGRAM_API_HASH is required for local TDLib."))
        }
        val databaseDirectory = requireString(args, "databaseDirectory")
        val filesDirectory = requireString(args, "filesDirectory")
        val encryptionKey = requireString(args, "encryptionKey")
        val telegramUserId = longArg(args, "telegramUserId") ?: 0L
        val version = stringArg(args, "applicationVersion") ?: tdlibAppVersion(context)
        File(databaseDirectory).mkdirs()
        File(filesDirectory).mkdirs()
        val nextScopeKey = "$databaseDirectory|$filesDirectory|$telegramUserId"
        synchronized(configureLock) {
            val previousScopeKey = activeScopeKey
            if (clientId != 0 && previousScopeKey != null && previousScopeKey != nextScopeKey) {
                closeAndResetClientBlocking(timeoutMs = 5000L)
            }
            config = Config(databaseDirectory, filesDirectory, apiId, apiHash, encryptionKey, telegramUserId, version)
            activeScopeKey = nextScopeKey
            ensureClient()
        }
        return send(JSONObject().put("@type", "getAuthorizationState"))
            .thenCompose {
                waitForAuthorizationState(
                    setOf(
                        "authorizationStateWaitPhoneNumber",
                        "authorizationStateWaitCode",
                        "authorizationStateWaitPassword",
                        "authorizationStateReady"
                    ),
                    timeoutMs = 20000L
                )
            }
            .thenApply { health() }
    }

    private fun closeAndResetClientBlocking(timeoutMs: Long) {
        val previousClientId = clientId
        if (previousClientId != 0) {
            val closeWaiter = CompletableFuture<String>()
            val waiter = AuthorizationWaiter(setOf("authorizationStateClosed"), closeWaiter)
            authorizationWaiters.add(waiter)
            try {
                JsonClient.send(previousClientId, JSONObject().put("@type", "close").toString())
                try {
                    closeWaiter.get(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
                } catch (_: Throwable) {
                    // Swallow timeout/interruption â€” we will force-reset state anyway.
                }
            } finally {
                authorizationWaiters.remove(waiter)
            }
        }
        val reconfigured = TdlibException("tdlib_reconfigured", "TDLib account changed.")
        for ((extra, future) in pending.toMap()) {
            future.completeExceptionally(reconfigured)
            pending.remove(extra)
        }
        for ((key, future) in sendWaiters.toMap()) {
            future.completeExceptionally(reconfigured)
            sendWaiters.remove(key)
        }
        completedSends.clear()
        failedSends.clear()
        for ((fileId, waiter) in downloads.toMap()) {
            waiter.future.completeExceptionally(reconfigured)
            downloads.remove(fileId)
        }
        for ((transferId, transfer) in transfers.toMap()) {
            transfer.cancelled = true
            emitProgress(transferId, "cancelled", 0, null, "TDLib account changed.")
            transfers.remove(transferId)
        }
        val authWaitersSnapshot = authorizationWaiters.toList()
        for (waiter in authWaitersSnapshot) {
            if (authorizationWaiters.remove(waiter)) {
                waiter.future.completeExceptionally(reconfigured)
            }
        }
        val connWaitersSnapshot = connectionWaiters.toList()
        for (waiter in connWaitersSnapshot) {
            if (connectionWaiters.remove(waiter)) {
                waiter.future.completeExceptionally(reconfigured)
            }
        }
        clientId = 0
        authorizationState = "authorizationStateClosed"
        connectionState = "connectionStateWaitingForNetwork"
    }

    fun resendCode(): CompletableFuture<Map<String, Any?>> {
        ensureReadyForAuth()
        return waitForAuthorizationState(setOf("authorizationStateWaitCode"), timeoutMs = 5000L)
            .thenCompose { send(JSONObject().put("@type", "resendAuthenticationCode")) }
            .thenCompose {
                waitForAuthorizationState(
                    setOf(
                        "authorizationStateWaitCode",
                        "authorizationStateWaitPassword",
                        "authorizationStateReady"
                    ),
                    timeoutMs = 20000L
                )
            }
            .thenApply { health() }
    }

    fun health(): Map<String, Any?> = mapOf(
        "available" to loaded,
        "configured" to (clientId != 0 && config != null),
        "authorizationState" to authorizationState,
        "connectionState" to connectionState,
        "authorized" to (authorizationState == "authorizationStateReady"),
        "loadError" to loadError?.message
    )

    fun setPhoneNumber(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        ensureReadyForAuth()
        val phoneNumber = requireString(args, "phoneNumber")
        return waitForAuthorizationState(setOf("authorizationStateWaitPhoneNumber"), timeoutMs = 15000L)
            .thenCompose {
                send(
                    JSONObject()
                        .put("@type", "setAuthenticationPhoneNumber")
                        .put("phone_number", phoneNumber)
                )
            }
            .thenCompose {
                waitForAuthorizationState(
                    setOf(
                        "authorizationStateWaitCode",
                        "authorizationStateWaitPassword",
                        "authorizationStateReady"
                    ),
                    timeoutMs = 20000L
                )
            }
            .thenApply { health() }
    }

    fun checkCode(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        ensureReadyForAuth()
        val code = requireString(args, "code")
        return waitForAuthorizationState(setOf("authorizationStateWaitCode"), timeoutMs = 5000L)
            .thenCompose { send(JSONObject().put("@type", "checkAuthenticationCode").put("code", code)) }
            .thenCompose {
                waitForAuthorizationState(
                    setOf("authorizationStateWaitPassword", "authorizationStateReady"),
                    timeoutMs = 20000L
                )
            }
            .thenApply { health() }
    }

    fun checkPassword(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        ensureReadyForAuth()
        val password = requireString(args, "password")
        return waitForAuthorizationState(setOf("authorizationStateWaitPassword"), timeoutMs = 5000L)
            .thenCompose { send(JSONObject().put("@type", "checkAuthenticationPassword").put("password", password)) }
            .thenCompose { waitForAuthorizationState(setOf("authorizationStateReady"), timeoutMs = 20000L) }
            .thenApply { health() }
    }

    fun getMe(): CompletableFuture<Map<String, Any?>> {
        ensureAuthorized()
        val expected = config?.expectedTelegramUserId ?: 0L
        return waitForConnectionReady(timeoutMs = 45000L).thenCompose {
            send(JSONObject().put("@type", "getMe"))
        }.thenApply { user ->
            val actual = user.optLong("id", 0L)
            if (expected > 0 && actual > 0 && actual != expected) {
                throw TdlibException("tdlib_account_mismatch", "Local TDLib account does not match the active TeleDrive account.", "expected=$expected actual=$actual")
            }
            jsonToMap(user)
        }
    }

    fun resolveChat(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        ensureAuthorized()
        return waitForConnectionReady(timeoutMs = 45000L).thenCompose {
            resolveChatAfterConnectionReady(args)
        }
    }

    fun sendDocument(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        ensureAuthorized()
        val transferId = requireString(args, "transferId")
        val chatId = longArg(args, "chatId") ?: throw TdlibException("tdlib_target_unresolved", "TDLib chat id is required.")
        val filePath = requireString(args, "filePath")
        val filename = stringArg(args, "filename") ?: File(filePath).name
        val mimeType = stringArg(args, "mimeType")
        val sizeBytes = longArg(args, "sizeBytes")
        val transfer = Transfer(transferId)
        transfers[transferId] = transfer
        emitProgress(transferId, "uploading", 0, sizeBytes, null)

        val inputContent = JSONObject()
            .put("@type", "inputMessageDocument")
            .put("document", JSONObject().put("@type", "inputFileLocal").put("path", filePath))
            .put("disable_content_type_detection", false)
            .put("caption", JSONObject().put("@type", "formattedText").put("text", "").put("entities", JSONArray()))

        val request = JSONObject()
            .put("@type", "sendMessage")
            .put("chat_id", chatId)
            .put("input_message_content", inputContent)

        val operation = waitForConnectionReady(timeoutMs = 45000L).thenCompose {
            send(request)
        }.thenCompose { message ->
            extractFile(message)?.let { transfer.fileId = it.optInt("id").takeIf { id -> id > 0 } }
            if (isFinalMessage(message)) {
                CompletableFuture.completedFuture(message)
            } else {
                val oldId = message.optLong("id", 0L)
                emitProgress(transferId, "waitingForFinalMessage", 0, sizeBytes, null)
                waitForFinalMessage("$chatId:$oldId", transferId, sizeBytes)
            }
        }.thenApply { finalMessage ->
            if (transfer.cancelled) {
                throw TdlibException("tdlib_cancelled", "Transfer was cancelled.")
            }
            val ref = messageRef(finalMessage, filename, mimeType, sizeBytes)
            emitProgress(transferId, "completed", sizeBytes ?: 0L, sizeBytes, null)
            transfers.remove(transferId)
            ref
        }
        return operation.whenComplete { _, error ->
            if (error != null) {
                transfers.remove(transferId)
            }
        }
    }

    fun downloadToFile(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        ensureAuthorized()
        val transferId = stringArg(args, "transferId") ?: UUID.randomUUID().toString()
        val chatId = longArg(args, "tdlibChatId") ?: throw TdlibException("tdlib_ref_invalid", "TDLib chat id is required.")
        val messageId = longArg(args, "tdlibMessageId") ?: throw TdlibException("tdlib_ref_invalid", "TDLib message id is required.")
        val destinationPath = requireString(args, "destinationPath")
        val suppliedFileId = intArg(args, "tdlibFileId")?.takeIf { it > 0 }
        val remoteFileId = stringArg(args, "tdlibRemoteFileId")?.takeIf { it.isNotBlank() }
        val messageFuture = waitForConnectionReady(timeoutMs = 45000L).thenCompose {
            send(JSONObject().put("@type", "getMessage").put("chat_id", chatId).put("message_id", messageId))
        }.handle<JSONObject?> { message, _ -> message }
        emitProgress(transferId, "downloading", 0, null, null)
        return messageFuture.thenCompose { message ->
            val messageFileId = extractFile(message ?: JSONObject())?.optInt("id")?.takeIf { it > 0 }
            if (messageFileId != null) {
                return@thenCompose startDownloadFile(messageFileId, transferId, destinationPath)
            }
            if (remoteFileId != null) {
                return@thenCompose remoteFile(remoteFileId).handle<CompletableFuture<Map<String, Any?>>> { file, error ->
                    val remoteResolvedFileId = if (error == null) file?.optInt("id")?.takeIf { it > 0 } else null
                    when {
                        remoteResolvedFileId != null -> startDownloadFile(remoteResolvedFileId, transferId, destinationPath)
                        suppliedFileId != null -> startDownloadFile(suppliedFileId, transferId, destinationPath)
                        error != null -> failed(error)
                        else -> failed(TdlibException("tdlib_file_ref_missing", "Could not locate TDLib file id for this message."))
                    }
                }.thenCompose { it }
            }
            if (suppliedFileId != null) {
                startDownloadFile(suppliedFileId, transferId, destinationPath)
            } else {
                failed(TdlibException("tdlib_file_ref_missing", "Could not locate TDLib file id for this message."))
            }
        }
    }

    private fun remoteFile(remoteFileId: String): CompletableFuture<JSONObject> {
        return send(
            JSONObject()
                .put("@type", "getRemoteFile")
                .put("remote_file_id", remoteFileId)
                .put("file_type", JSONObject().put("@type", "fileTypeUnknown"))
        )
    }

    private fun startDownloadFile(
        fileId: Int,
        transferId: String,
        destinationPath: String
    ): CompletableFuture<Map<String, Any?>> {
        val waiter = DownloadWaiter(transferId, destinationPath, CompletableFuture())
        downloads[fileId] = waiter
        transfers[transferId] = Transfer(transferId, fileId)
        send(
            JSONObject()
                .put("@type", "downloadFile")
                .put("file_id", fileId)
                .put("priority", 32)
                .put("offset", 0)
                .put("limit", 0)
                .put("synchronous", false)
        ).whenComplete { file, error ->
            if (error != null) {
                downloads.remove(fileId)
                transfers.remove(transferId)
                emitProgress(transferId, "failed", 0, null, error.message)
                waiter.future.completeExceptionally(error)
            } else if (file != null) {
                handleDownloadedFile(file)
                val local = file.optJSONObject("local")
                if (local?.optBoolean("is_downloading_completed", false) != true) {
                    val remote = file.optJSONObject("remote")
                    if (remote?.optBoolean("is_uploading_completed", true) == false) {
                        downloads.remove(fileId)
                        transfers.remove(transferId)
                        waiter.future.completeExceptionally(
                            TdlibException("tdlib_file_unavailable", "Telegram file is not ready to download.")
                        )
                    }
                }
            }
        }
        expireDownloadWaiter(fileId, waiter, timeoutMs = 45000L)
        return waiter.future
    }

    fun cancelTransfer(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        val transferId = requireString(args, "transferId")
        val transfer = transfers[transferId]
        transfer?.cancelled = true
        val fileId = transfer?.fileId
        if (clientId != 0 && fileId != null) {
            sendNoWait(JSONObject().put("@type", "cancelDownloadFile").put("file_id", fileId).put("only_if_pending", false))
            sendNoWait(JSONObject().put("@type", "cancelUploadFile").put("file_id", fileId))
        }
        emitProgress(transferId, "cancelled", 0, null, null)
        return CompletableFuture.completedFuture(mapOf("cancelled" to true))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun ensureClient() {
        if (clientId == 0) {
            clientId = JsonClient.createClientId()
        }
        if (!receiverStarted) {
            receiverStarted = true
            thread(name = "teledrive-tdlib-receiver", isDaemon = true) {
                while (receiverStarted) {
                    try {
                        val payload = JsonClient.receive(1.0) ?: continue
                        handleUpdate(JSONObject(payload))
                    } catch (error: Throwable) {
                        emitError("tdlib_receive_error", error.message ?: "TDLib receive failed.")
                    }
                }
            }
        }
    }

    private fun handleUpdate(json: JSONObject) {
        val type = json.optString("@type")
        val extra = json.optString("@extra", null)
        if (extra != null && pending.containsKey(extra)) {
            val future = pending.remove(extra)
            if (type == "error") {
                future?.completeExceptionally(TdlibException("tdlib_${json.optInt("code", 0)}", json.optString("message", "TDLib error"), json.toString()))
            } else {
                future?.complete(json)
            }
        }
        when (type) {
            "updateAuthorizationState" -> handleAuthorizationState(json.getJSONObject("authorization_state"))
            "authorizationStateReady",
            "authorizationStateWaitPhoneNumber",
            "authorizationStateWaitCode",
            "authorizationStateWaitPassword",
            "authorizationStateWaitTdlibParameters",
            "authorizationStateWaitEncryptionKey",
            "authorizationStateClosed" -> handleAuthorizationState(json)
            "updateConnectionState" -> handleConnectionState(json.getJSONObject("state"))
            "updateMessageSendSucceeded" -> handleSendSucceeded(json)
            "updateMessageSendFailed" -> handleSendFailed(json)
            "updateFile" -> handleUpdatedFile(json.getJSONObject("file"))
        }
    }

    private fun handleAuthorizationState(state: JSONObject) {
        authorizationState = state.optString("@type", authorizationState)
        when (authorizationState) {
            "authorizationStateWaitTdlibParameters" -> config?.let { cfg ->
                sendNoWait(
                    JSONObject()
                        .put("@type", "setTdlibParameters")
                        .put("use_test_dc", false)
                        .put("database_directory", cfg.databaseDirectory)
                        .put("files_directory", cfg.filesDirectory)
                        .put("database_encryption_key", cfg.encryptionKey)
                        .put("use_file_database", true)
                        .put("use_chat_info_database", true)
                        .put("use_message_database", true)
                        .put("use_secret_chats", false)
                        .put("api_id", cfg.apiId)
                        .put("api_hash", cfg.apiHash)
                        .put("system_language_code", "en")
                        .put("device_model", "${Build.MANUFACTURER} ${Build.MODEL}".trim())
                        .put("system_version", "Android ${Build.VERSION.RELEASE}")
                        .put("application_version", cfg.applicationVersion)
                )
            }
            "authorizationStateWaitEncryptionKey" -> config?.let { cfg ->
                sendNoWait(JSONObject().put("@type", "checkDatabaseEncryptionKey").put("encryption_key", cfg.encryptionKey))
            }
        }
        completeAuthorizationWaiters(authorizationState)
        mainHandler.post { eventSink?.success(mapOf("type" to "authorization", "authorizationState" to authorizationState)) }
    }

    private fun handleConnectionState(state: JSONObject) {
        connectionState = state.optString("@type", connectionState)
        completeConnectionWaiters(connectionState)
        mainHandler.post { eventSink?.success(mapOf("type" to "connection", "connectionState" to connectionState)) }
    }

    private fun waitForAuthorizationState(
        acceptedStates: Set<String>,
        timeoutMs: Long
    ): CompletableFuture<String> {
        val current = authorizationState
        if (acceptedStates.contains(current)) {
            return CompletableFuture.completedFuture(current)
        }
        val future = CompletableFuture<String>()
        val waiter = AuthorizationWaiter(acceptedStates, future)
        authorizationWaiters.add(waiter)
        thread(name = "teledrive-tdlib-auth-timeout", isDaemon = true) {
            try {
                Thread.sleep(timeoutMs)
                if (!future.isDone) {
                    authorizationWaiters.remove(waiter)
                    future.completeExceptionally(
                        TdlibException(
                            "tdlib_auth_state_timeout",
                            "Timed out waiting for TDLib authorization state.",
                            "current=$authorizationState accepted=${acceptedStates.joinToString(",")}"
                        )
                    )
                }
            } catch (_: InterruptedException) {
            }
        }
        return future
    }

    private fun completeAuthorizationWaiters(state: String) {
        for (waiter in authorizationWaiters) {
            if (waiter.acceptedStates.contains(state) && authorizationWaiters.remove(waiter)) {
                waiter.future.complete(state)
            }
        }
    }

    private fun waitForConnectionReady(timeoutMs: Long): CompletableFuture<String> {
        if (connectionState == "connectionStateReady") {
            return CompletableFuture.completedFuture(connectionState)
        }
        sendNoWait(JSONObject().put("@type", "getCurrentState"))
        val future = CompletableFuture<String>()
        val waiter = ConnectionWaiter(setOf("connectionStateReady"), future)
        connectionWaiters.add(waiter)
        thread(name = "teledrive-tdlib-connection-timeout", isDaemon = true) {
            try {
                Thread.sleep(timeoutMs)
                if (!future.isDone) {
                    connectionWaiters.remove(waiter)
                    future.completeExceptionally(
                        TdlibException(
                            "tdlib_connection_timeout",
                            "Timed out waiting for TDLib network connection.",
                            connectionState
                        )
                    )
                }
            } catch (_: InterruptedException) {
            }
        }
        return future
    }

    private fun completeConnectionWaiters(state: String) {
        for (waiter in connectionWaiters) {
            if (waiter.acceptedStates.contains(state) && connectionWaiters.remove(waiter)) {
                waiter.future.complete(state)
            }
        }
    }

    private fun resolveChatAfterConnectionReady(args: Map<String, Any?>): CompletableFuture<Map<String, Any?>> {
        val provided = longArg(args, "tdlibChatId")
        if (provided != null && provided != 0L) {
            return getChatWithRefresh(provided, stringArg(args, "title"))
        }
        val channelId = longArg(args, "telethonChannelId") ?: channelIdFromPeer(longArg(args, "telethonPeerId"))
        if (channelId == null || channelId == 0L) {
            return failed(TdlibException("tdlib_target_unresolved", "Backend did not provide a resolvable Telegram channel id."))
        }
        val tdlibChatId = -1000000000000L - kotlin.math.abs(channelId)
        return getChatWithRefresh(tdlibChatId, stringArg(args, "title"))
    }

    private fun getChatWithRefresh(chatId: Long, title: String?): CompletableFuture<Map<String, Any?>> {
        return send(JSONObject().put("@type", "getChat").put("chat_id", chatId))
            .handle<CompletableFuture<Map<String, Any?>>> { chat, error ->
                if (error == null) {
                    CompletableFuture.completedFuture(chatResult(chat))
                } else {
                    refreshChats(title).thenCompose {
                        send(JSONObject().put("@type", "getChat").put("chat_id", chatId)).thenApply { chatResult(it) }
                    }
                }
            }
            .thenCompose { it }
    }

    private fun refreshChats(title: String?): CompletableFuture<Unit> {
        val mainList = JSONObject().put("@type", "chatListMain")
        val loadMain = send(
            JSONObject()
                .put("@type", "loadChats")
                .put("chat_list", mainList)
                .put("limit", 100)
        ).handle { _, _ -> Unit }
        if (title.isNullOrBlank()) return loadMain
        return loadMain.thenCompose {
            send(
                JSONObject()
                    .put("@type", "searchChatsOnServer")
                    .put("query", title)
                    .put("limit", 20)
            ).handle { _, _ -> Unit }
        }
    }

    private fun handleSendSucceeded(update: JSONObject) {
        val message = update.getJSONObject("message")
        val oldId = update.optLong("old_message_id", 0L)
        val chatId = message.optLong("chat_id", 0L)
        val key = "$chatId:$oldId"
        val waiter = sendWaiters.remove(key)
        if (waiter != null) {
            waiter.complete(message)
        } else {
            cacheCompletedSend(key, message)
        }
    }

    private fun handleSendFailed(update: JSONObject) {
        val message = update.optJSONObject("message")
        val oldId = update.optLong("old_message_id", 0L)
        val chatId = message?.optLong("chat_id", 0L) ?: 0L
        val key = "$chatId:$oldId"
        val error = TdlibException("tdlib_send_failed", update.optString("error_message", "TDLib send failed."), update.toString())
        val waiter = sendWaiters.remove(key)
        if (waiter != null) {
            waiter.completeExceptionally(error)
        } else {
            cacheFailedSend(key, error)
        }
    }

    private fun waitForFinalMessage(key: String, transferId: String, sizeBytes: Long?): CompletableFuture<JSONObject> {
        completedSends.remove(key)?.let { return CompletableFuture.completedFuture(it) }
        failedSends.remove(key)?.let { return failed(it) }

        val waiter = CompletableFuture<JSONObject>()
        sendWaiters[key] = waiter

        completedSends.remove(key)?.let { message ->
            if (sendWaiters.remove(key, waiter)) {
                waiter.complete(message)
            }
        }
        failedSends.remove(key)?.let { error ->
            if (sendWaiters.remove(key, waiter)) {
                waiter.completeExceptionally(error)
            }
        }

        val timeoutMs = uploadTimeoutMs(sizeBytes)
        thread(name = "teledrive-tdlib-send-timeout", isDaemon = true) {
            try {
                Thread.sleep(timeoutMs)
                if (sendWaiters.remove(key, waiter)) {
                    transfers.remove(transferId)
                    emitProgress(transferId, "failed", 0, sizeBytes, "Timed out waiting for Telegram to confirm the upload.")
                    waiter.completeExceptionally(
                        TdlibException(
                            "tdlib_send_timeout",
                            "Timed out waiting for Telegram to confirm the upload.",
                            "key=$key timeoutMs=$timeoutMs"
                        )
                    )
                }
            } catch (_: InterruptedException) {
            }
        }

        return waiter
    }

    private fun cacheCompletedSend(key: String, message: JSONObject) {
        completedSends[key] = message
        expireCachedSend(key)
    }

    private fun cacheFailedSend(key: String, error: TdlibException) {
        failedSends[key] = error
        expireCachedSend(key)
    }

    private fun expireCachedSend(key: String) {
        thread(name = "teledrive-tdlib-send-cache-expiry", isDaemon = true) {
            try {
                Thread.sleep(10 * 60 * 1000L)
                completedSends.remove(key)
                failedSends.remove(key)
            } catch (_: InterruptedException) {
            }
        }
    }

    private fun uploadTimeoutMs(sizeBytes: Long?): Long {
        val size = sizeBytes ?: 0L
        val mib = size / (1024L * 1024L)
        return (10 * 60 * 1000L + mib * 60 * 1000L).coerceAtMost(60 * 60 * 1000L)
    }

    private fun handleUpdatedFile(file: JSONObject) {
        val fileId = file.optInt("id", 0)
        val size = file.optLong("size", 0L).takeIf { it > 0 }
        val local = file.optJSONObject("local")
        val remote = file.optJSONObject("remote")
        val downloaded = local?.optBoolean("is_downloading_completed", false) == true
        val downloadedBytes = local?.optLong("downloaded_size", 0L) ?: 0L
        val uploadedBytes = remote?.optLong("uploaded_size", 0L) ?: 0L
        transfers.values.filter { it.fileId == fileId }.forEach { transfer ->
            if (downloads.containsKey(fileId)) {
                emitProgress(transfer.transferId, "downloading", downloadedBytes, size, null)
            } else {
                emitProgress(transfer.transferId, "uploading", uploadedBytes, size, null)
            }
        }
        if (downloaded) {
            handleDownloadedFile(file)
        }
    }

    private fun handleDownloadedFile(file: JSONObject) {
        val fileId = file.optInt("id", 0)
        val waiter = downloads[fileId] ?: return
        val sourcePath = file.optJSONObject("local")?.optString("path", null)
        if (sourcePath.isNullOrBlank()) return
        try {
            val source = File(sourcePath)
            val dest = File(waiter.destinationPath)
            dest.parentFile?.mkdirs()
            if (source.absolutePath != dest.absolutePath) {
                source.copyTo(dest, overwrite = true)
            }
            downloads.remove(fileId)
            transfers.remove(waiter.transferId)
            emitProgress(waiter.transferId, "completed", source.length(), source.length(), null)
            waiter.future.complete(mapOf("filePath" to dest.absolutePath, "tdlibFileId" to fileId))
        } catch (error: Throwable) {
            downloads.remove(fileId)
            waiter.future.completeExceptionally(TdlibException("tdlib_download_copy_failed", error.message ?: "Could not copy downloaded file."))
        }
    }

    private fun expireDownloadWaiter(fileId: Int, waiter: DownloadWaiter, timeoutMs: Long) {
        thread(name = "teledrive-tdlib-download-timeout", isDaemon = true) {
            try {
                Thread.sleep(timeoutMs)
                if (downloads.remove(fileId, waiter)) {
                    transfers.remove(waiter.transferId)
                    emitProgress(waiter.transferId, "failed", 0, null, "Timed out waiting for Telegram to download the file.")
                    waiter.future.completeExceptionally(
                        TdlibException(
                            "tdlib_download_timeout",
                            "Timed out waiting for Telegram to download the file.",
                            "fileId=$fileId timeoutMs=$timeoutMs"
                        )
                    )
                }
            } catch (_: InterruptedException) {
            }
        }
    }

    private fun send(request: JSONObject): CompletableFuture<JSONObject> {
        ensureClient()
        val extra = UUID.randomUUID().toString()
        request.put("@extra", extra)
        val future = CompletableFuture<JSONObject>()
        pending[extra] = future
        JsonClient.send(clientId, request.toString())
        return future
    }

    private fun sendNoWait(request: JSONObject) {
        ensureClient()
        JsonClient.send(clientId, request.toString())
    }

    private fun ensureReadyForAuth() {
        if (!loaded) throw TdlibException("tdlib_unavailable", "TDLib is unavailable.")
        ensureClient()
    }

    private fun ensureAuthorized() {
        ensureReadyForAuth()
        if (authorizationState != "authorizationStateReady") {
            throw TdlibException("tdlib_auth_required", "Local TDLib is not authorized.", authorizationState)
        }
    }

    private fun chatResult(chat: JSONObject): Map<String, Any?> = mapOf(
        "tdlibChatId" to chat.optLong("id"),
        "title" to chat.optString("title", null),
        "type" to chat.optJSONObject("type")?.optString("@type", null)
    )

    private fun messageRef(message: JSONObject, fallbackFilename: String, fallbackMime: String?, fallbackSize: Long?): Map<String, Any?> {
        val file = extractFile(message)
        val content = message.optJSONObject("content")
        val document = content?.optJSONObject("document")
        val remote = file?.optJSONObject("remote")
        return mapOf(
            "tdlibChatId" to message.optLong("chat_id", 0L),
            "tdlibMessageId" to message.optLong("id", 0L),
            "tdlibFileId" to (file?.optInt("id")?.takeIf { it > 0 }),
            "tdlibRemoteFileId" to remote?.optString("id", null),
            "sizeBytes" to (file?.optLong("size", 0L)?.takeIf { it > 0 } ?: fallbackSize),
            "mimeType" to (document?.optString("mime_type", null) ?: fallbackMime),
            "filename" to (document?.optString("file_name", null)?.takeIf { it.isNotBlank() } ?: fallbackFilename)
        )
    }

    private fun extractFile(message: JSONObject): JSONObject? {
        val content = message.optJSONObject("content") ?: return null
        return when (content.optString("@type")) {
            "messageDocument" -> content.optJSONObject("document")?.optJSONObject("document")
            "messageVideo" -> content.optJSONObject("video")?.optJSONObject("video")
            "messageAnimation" -> content.optJSONObject("animation")?.optJSONObject("animation")
            "messageAudio" -> content.optJSONObject("audio")?.optJSONObject("audio")
            "messageVoiceNote" -> content.optJSONObject("voice_note")?.optJSONObject("voice")
            "messagePhoto" -> largestPhotoFile(content.optJSONObject("photo")?.optJSONArray("sizes"))
            else -> null
        }
    }

    private fun largestPhotoFile(sizes: JSONArray?): JSONObject? {
        if (sizes == null) return null
        var best: JSONObject? = null
        var bestArea = -1
        for (index in 0 until sizes.length()) {
            val size = sizes.optJSONObject(index) ?: continue
            val area = size.optInt("width", 0) * size.optInt("height", 0)
            if (area > bestArea) {
                bestArea = area
                best = size.optJSONObject("photo")
            }
        }
        return best
    }

    private fun isFinalMessage(message: JSONObject): Boolean {
        return message.optLong("id", 0L) > 0 && !message.has("sending_state")
    }

    private fun channelIdFromPeer(peerId: Long?): Long? {
        if (peerId == null || peerId == 0L) return null
        val text = kotlin.math.abs(peerId).toString()
        return if (text.startsWith("100") && text.length > 3) text.substring(3).toLongOrNull() else kotlin.math.abs(peerId)
    }

    private fun emitProgress(transferId: String, state: String, bytesDone: Long, totalBytes: Long?, message: String?) {
        if (state in terminalStates) {
            lastEmittedAtByTransferId.remove(transferId)
            lastEmittedFractionByTransferId.remove(transferId)
            lastEmittedStateByTransferId.remove(transferId)
            // fall through â€” terminal events ALWAYS post, never throttled
        } else {
            val prevState = lastEmittedStateByTransferId[transferId]
            val stateChanged = prevState != state
            val now = SystemClock.uptimeMillis()
            val last = lastEmittedAtByTransferId[transferId] ?: 0L
            val frac = if (totalBytes != null && totalBytes > 0L) {
                ((bytesDone * 1000L) / totalBytes).toInt().coerceIn(0, 1000)
            } else {
                -1
            }
            val lastFrac = lastEmittedFractionByTransferId[transferId] ?: -1
            val withinInterval = now - last < progressMinIntervalMs
            val bigJump = frac >= 0 && lastFrac >= 0 && kotlin.math.abs(frac - lastFrac) >= 10
            if (!stateChanged && last != 0L && withinInterval && !bigJump) return
            lastEmittedAtByTransferId[transferId] = now
            if (frac >= 0) lastEmittedFractionByTransferId[transferId] = frac
            lastEmittedStateByTransferId[transferId] = state
        }
        val event = mapOf(
            "type" to "progress",
            "transferId" to transferId,
            "state" to state,
            "bytesDone" to bytesDone,
            "totalBytes" to totalBytes,
            "message" to message
        )
        mainHandler.post { eventSink?.success(event) }
    }

    private fun emitError(code: String, message: String) {
        mainHandler.post { eventSink?.success(mapOf("type" to "error", "code" to code, "message" to message)) }
    }

}


