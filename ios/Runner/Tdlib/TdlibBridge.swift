import Flutter
import Foundation

/// 1:1 port of the Android TdlibBridge (TdlibBridge.kt). The Dart layer talks
/// to it over MethodChannel "teledrive/tdlib" and EventChannel
/// "teledrive/tdlib/events"; method names, argument coercion, result map
/// shapes, error codes, and event payloads must match the Kotlin bridge
/// exactly so the Dart side needs no platform-specific code.
///
/// Threading model:
/// - `methodQueue` (serial) runs every method call, so configure's blocking
///   close never stalls the main thread.
/// - One daemon receiver thread loops td_receive and dispatches updates.
/// - `stateLock` guards all mutable state. Promises are never settled while
///   the lock is held — their callbacks re-enter the bridge (send → lock).
/// - FlutterResult and FlutterEventSink are only invoked on the main thread.
final class TdlibBridge: NSObject {
    let methodQueue = DispatchQueue(label: "teledrive.tdlib.methods")
    private let timeoutQueue = DispatchQueue.global(qos: .utility)
    private let stateLock = NSLock()

    // All fields below are guarded by stateLock unless noted otherwise.
    private var pending: [String: Promise<[String: Any]>] = [:]
    var sendWaiters: [String: Promise<[String: Any]>] = [:]
    var completedSends: [String: [String: Any]] = [:]
    var failedSends: [String: TdlibError] = [:]
    var downloads: [Int: [TdlibDownloadWaiter]] = [:]
    var transfers: [String: TdlibTransfer] = [:]
    private var authorizationWaiters: [TdlibAuthorizationWaiter] = []
    private var connectionWaiters: [TdlibConnectionWaiter] = []
    var lastEmittedAtByTransferId: [String: Int64] = [:]
    var lastEmittedFractionByTransferId: [String: Int] = [:]
    var lastEmittedStateByTransferId: [String: String] = [:]
    private var clientId: Int32 = 0
    private var receiverStarted = false
    private var config: TdlibConfig?
    private var activeScopeKey: String?
    private var authorizationState = "authorizationStateClosed"
    private var connectionState = "connectionStateWaitingForNetwork"

    // Accessed only on the main thread (Flutter invokes the stream handler there).
    private var eventSink: FlutterEventSink?

    let terminalStates: Set<String> = ["completed", "failed", "cancelled"]
    let progressMinIntervalMs: Int64 = 250

    override init() {
        super.init()
        // TDLib's default verbosity floods the Xcode console; the Android
        // bridge never needed this because logcat noise goes unseen.
        TdlibJsonClient.execute(#"{"@type":"setLogVerbosityLevel","new_verbosity_level":1}"#)
    }

    // MARK: - Locking helpers

    func withLock<R>(_ body: () -> R) -> R {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    func scheduleTimeout(afterMs timeoutMs: Int, _ body: @escaping () -> Void) {
        timeoutQueue.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: body)
    }

    // MARK: - Method channel entry point (MainActivity.handleTdlibCall analogue)

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        methodQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "tdlib_error", message: "TDLib bridge failed.", details: nil))
                }
                return
            }
            do {
                switch call.method {
                case "isAvailable":
                    self.finishValue(result, self.isAvailable())
                case "configure":
                    self.finishPromise(try self.configure(args), result)
                case "health":
                    self.finishValue(result, self.health())
                case "getMe":
                    self.finishPromise(try self.getMe(), result)
                case "setPhoneNumber":
                    self.finishPromise(try self.setPhoneNumber(args), result)
                case "checkCode":
                    self.finishPromise(try self.checkCode(args), result)
                case "checkPassword":
                    self.finishPromise(try self.checkPassword(args), result)
                case "resendCode":
                    self.finishPromise(try self.resendCode(), result)
                case "resolveChat":
                    self.finishPromise(try self.resolveChat(args), result)
                case "sendDocument":
                    self.finishPromise(try self.sendDocument(args), result)
                case "downloadToFile":
                    self.finishPromise(try self.downloadToFile(args), result)
                case "cancelTransfer":
                    self.finishValue(result, try self.cancelTransfer(args))
                default:
                    DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
                }
            } catch let error as TdlibError {
                DispatchQueue.main.async {
                    result(FlutterError(code: error.code, message: error.message, details: error.details))
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "tdlib_error", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func finishValue(_ result: @escaping FlutterResult, _ value: Any) {
        DispatchQueue.main.async { result(value) }
    }

    private func finishPromise(_ promise: Promise<[String: Any]>, _ result: @escaping FlutterResult) {
        promise.onComplete { outcome in
            DispatchQueue.main.async {
                switch outcome {
                case .success(let value):
                    result(value)
                case .failure(let error):
                    if let tdlibError = error as? TdlibError {
                        result(FlutterError(code: tdlibError.code, message: tdlibError.message, details: tdlibError.details))
                    } else {
                        result(FlutterError(code: "tdlib_error", message: error.localizedDescription, details: nil))
                    }
                }
            }
        }
    }

    // MARK: - Availability and health

    /// The framework is statically linked, so unlike Android's per-ABI .so
    /// load this cannot fail at runtime.
    func isAvailable() -> Bool {
        return true
    }

    func health() -> [String: Any] {
        return withLock {
            [
                "available": true,
                "configured": clientId != 0 && config != nil,
                "authorizationState": authorizationState,
                "connectionState": connectionState,
                "authorized": authorizationState == "authorizationStateReady",
                "loadError": NSNull(),
            ]
        }
    }

    // MARK: - Configure

    func configure(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        guard let apiId = TdlibArgs.int(args, "apiId") else {
            throw TdlibError("tdlib_api_credentials_missing", "TELEGRAM_API_ID is required for local TDLib.")
        }
        guard let apiHash = TdlibArgs.string(args, "apiHash"), !TdlibArgs.isBlank(apiHash) else {
            throw TdlibError("tdlib_api_credentials_missing", "TELEGRAM_API_HASH is required for local TDLib.")
        }
        let databaseDirectory = try TdlibArgs.requireString(args, "databaseDirectory")
        let filesDirectory = try TdlibArgs.requireString(args, "filesDirectory")
        let encryptionKey = try TdlibArgs.requireString(args, "encryptionKey")
        let telegramUserId = TdlibArgs.int64(args, "telegramUserId") ?? 0
        let version = TdlibArgs.string(args, "applicationVersion") ?? TdlibDeviceInfo.fallbackApplicationVersion
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: databaseDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(atPath: filesDirectory, withIntermediateDirectories: true)
        excludeFromBackup(databaseDirectory)
        excludeFromBackup(filesDirectory)
        let nextScopeKey = "\(databaseDirectory)|\(filesDirectory)|\(telegramUserId)"

        // The serial method queue plays the role of Kotlin's configureLock.
        let shouldClose = withLock {
            clientId != 0 && activeScopeKey != nil && activeScopeKey != nextScopeKey
        }
        if shouldClose {
            closeAndResetClientBlocking(timeoutMs: 5000)
        }
        withLock {
            config = TdlibConfig(
                databaseDirectory: databaseDirectory,
                filesDirectory: filesDirectory,
                apiId: apiId,
                apiHash: apiHash,
                encryptionKey: encryptionKey,
                expectedTelegramUserId: telegramUserId,
                applicationVersion: version
            )
            activeScopeKey = nextScopeKey
        }
        ensureClient()

        return send(["@type": "getAuthorizationState"])
            .then { _ in
                self.waitForAuthorizationState(
                    [
                        "authorizationStateWaitPhoneNumber",
                        "authorizationStateWaitCode",
                        "authorizationStateWaitPassword",
                        "authorizationStateReady",
                    ],
                    timeoutMs: 20000
                )
            }
            .map { _ in self.health() }
    }

    /// TDLib session keys and the message database must not ride iCloud
    /// backups onto other devices; a restored session would be dead anyway
    /// and Telegram would force a re-login.
    private func excludeFromBackup(_ path: String) {
        var url = URL(fileURLWithPath: path)
        var candidate = url
        while candidate.pathComponents.count > 1 {
            if candidate.lastPathComponent == "tdlib" {
                url = candidate
                break
            }
            candidate.deleteLastPathComponent()
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func closeAndResetClientBlocking(timeoutMs: Int) {
        let previousClientId = withLock { clientId }
        if previousClientId != 0 {
            let closePromise = Promise<String>()
            let waiter = TdlibAuthorizationWaiter(acceptedStates: ["authorizationStateClosed"], promise: closePromise)
            withLock { authorizationWaiters.append(waiter) }
            TdlibJsonClient.send(previousClientId, TdlibJson.string(["@type": "close"]))
            // Swallow timeouts — state is force-reset below either way.
            _ = closePromise.wait(timeoutMs: timeoutMs)
            withLock {
                if let index = authorizationWaiters.firstIndex(where: { $0 === waiter }) {
                    authorizationWaiters.remove(at: index)
                }
            }
        }
        let reconfigured = TdlibError("tdlib_reconfigured", "TDLib account changed.")
        var pendingSnapshot: [Promise<[String: Any]>] = []
        var sendWaiterSnapshot: [Promise<[String: Any]>] = []
        var downloadSnapshot: [TdlibDownloadWaiter] = []
        var cancelledTransferIds: [String] = []
        var authorizationSnapshot: [TdlibAuthorizationWaiter] = []
        var connectionSnapshot: [TdlibConnectionWaiter] = []
        withLock {
            pendingSnapshot = Array(pending.values)
            pending.removeAll()
            sendWaiterSnapshot = Array(sendWaiters.values)
            sendWaiters.removeAll()
            completedSends.removeAll()
            failedSends.removeAll()
            downloadSnapshot = downloads.values.flatMap { $0 }
            downloads.removeAll()
            for (transferId, transfer) in transfers {
                transfer.cancelled = true
                cancelledTransferIds.append(transferId)
            }
            transfers.removeAll()
            authorizationSnapshot = authorizationWaiters
            authorizationWaiters.removeAll()
            connectionSnapshot = connectionWaiters
            connectionWaiters.removeAll()
            clientId = 0
            authorizationState = "authorizationStateClosed"
            connectionState = "connectionStateWaitingForNetwork"
        }
        pendingSnapshot.forEach { $0.fail(reconfigured) }
        sendWaiterSnapshot.forEach { $0.fail(reconfigured) }
        downloadSnapshot.forEach { $0.promise.fail(reconfigured) }
        cancelledTransferIds.forEach { emitProgress($0, "cancelled", 0, nil, "TDLib account changed.") }
        authorizationSnapshot.forEach { $0.promise.fail(reconfigured) }
        connectionSnapshot.forEach { $0.promise.fail(reconfigured) }
    }

    // MARK: - Authentication

    func setPhoneNumber(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        try ensureReadyForAuth()
        let phoneNumber = try TdlibArgs.requireString(args, "phoneNumber")
        return waitForAuthorizationState(["authorizationStateWaitPhoneNumber"], timeoutMs: 15000)
            .then { _ in
                self.send(["@type": "setAuthenticationPhoneNumber", "phone_number": phoneNumber])
            }
            .then { _ in
                self.waitForAuthorizationState(
                    ["authorizationStateWaitCode", "authorizationStateWaitPassword", "authorizationStateReady"],
                    timeoutMs: 20000
                )
            }
            .map { _ in self.health() }
    }

    func checkCode(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        try ensureReadyForAuth()
        let code = try TdlibArgs.requireString(args, "code")
        return waitForAuthorizationState(["authorizationStateWaitCode"], timeoutMs: 5000)
            .then { _ in
                self.send(["@type": "checkAuthenticationCode", "code": code])
            }
            .then { _ in
                self.waitForAuthorizationState(
                    ["authorizationStateWaitPassword", "authorizationStateReady"],
                    timeoutMs: 20000
                )
            }
            .map { _ in self.health() }
    }

    func checkPassword(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        try ensureReadyForAuth()
        let password = try TdlibArgs.requireString(args, "password")
        return waitForAuthorizationState(["authorizationStateWaitPassword"], timeoutMs: 5000)
            .then { _ in
                self.send(["@type": "checkAuthenticationPassword", "password": password])
            }
            .then { _ in
                self.waitForAuthorizationState(["authorizationStateReady"], timeoutMs: 20000)
            }
            .map { _ in self.health() }
    }

    func resendCode() throws -> Promise<[String: Any]> {
        try ensureReadyForAuth()
        return waitForAuthorizationState(["authorizationStateWaitCode"], timeoutMs: 5000)
            .then { _ in
                self.send(["@type": "resendAuthenticationCode"])
            }
            .then { _ in
                self.waitForAuthorizationState(
                    ["authorizationStateWaitCode", "authorizationStateWaitPassword", "authorizationStateReady"],
                    timeoutMs: 20000
                )
            }
            .map { _ in self.health() }
    }

    func getMe() throws -> Promise<[String: Any]> {
        try ensureAuthorized()
        let expected = withLock { config?.expectedTelegramUserId ?? 0 }
        return waitForConnectionReady(timeoutMs: 45000)
            .then { _ in
                self.send(["@type": "getMe"])
            }
            .map { user -> [String: Any] in
                let actual = TdlibJson.int64(user["id"]) ?? 0
                if expected > 0 && actual > 0 && actual != expected {
                    throw TdlibError(
                        "tdlib_account_mismatch",
                        "Local TDLib account does not match the active TeleDrive account.",
                        "expected=\(expected) actual=\(actual)"
                    )
                }
                return user
            }
    }

    // MARK: - Chat resolution

    func resolveChat(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        try ensureAuthorized()
        return waitForConnectionReady(timeoutMs: 45000).then { _ in
            self.resolveChatAfterConnectionReady(args)
        }
    }

    private func resolveChatAfterConnectionReady(_ args: [String: Any]) -> Promise<[String: Any]> {
        if let provided = TdlibArgs.int64(args, "tdlibChatId"), provided != 0 {
            return getChatWithRefresh(provided, TdlibArgs.string(args, "title"))
        }
        let channelId = TdlibArgs.int64(args, "telethonChannelId")
            ?? TdlibBridge.channelIdFromPeer(TdlibArgs.int64(args, "telethonPeerId"))
        guard let resolvedChannelId = channelId, resolvedChannelId != 0 else {
            return Promise.error(
                TdlibError("tdlib_target_unresolved", "Backend did not provide a resolvable Telegram channel id.")
            )
        }
        let tdlibChatId = -1_000_000_000_000 - abs(resolvedChannelId)
        return getChatWithRefresh(tdlibChatId, TdlibArgs.string(args, "title"))
    }

    private func getChatWithRefresh(_ chatId: Int64, _ title: String?) -> Promise<[String: Any]> {
        return send(["@type": "getChat", "chat_id": NSNumber(value: chatId)])
            .handle { chat, error -> Promise<[String: Any]> in
                if error == nil, let chat = chat {
                    return Promise.value(TdlibBridge.chatResult(chat))
                }
                return self.refreshChats(title).then { _ in
                    self.send(["@type": "getChat", "chat_id": NSNumber(value: chatId)])
                        .map { TdlibBridge.chatResult($0) }
                }
            }
            .then { $0 }
    }

    private func refreshChats(_ title: String?) -> Promise<Void> {
        let loadMain = send([
            "@type": "loadChats",
            "chat_list": ["@type": "chatListMain"] as [String: Any],
            "limit": 100,
        ]).handle { _, _ in () }
        guard let title = title, !TdlibArgs.isBlank(title) else { return loadMain }
        return loadMain.then { _ in
            self.send(["@type": "searchChatsOnServer", "query": title, "limit": 20])
                .handle { _, _ in () }
        }
    }

    // MARK: - Client lifecycle and receive loop

    func ensureClient() {
        var needStart = false
        withLock {
            if clientId == 0 {
                clientId = TdlibJsonClient.createClientId()
            }
            if !receiverStarted {
                receiverStarted = true
                needStart = true
            }
        }
        guard needStart else { return }
        let thread = Thread { [weak self] in
            while true {
                guard let payload = TdlibJsonClient.receive(1.0) else { continue }
                guard let self = self else { return }
                autoreleasepool {
                    if let json = TdlibJson.parse(payload) {
                        self.handleUpdate(json)
                    } else {
                        self.emitError("tdlib_receive_error", "TDLib receive failed.")
                    }
                }
            }
        }
        thread.name = "teledrive-tdlib-receiver"
        thread.qualityOfService = .utility
        thread.start()
    }

    private func handleUpdate(_ json: [String: Any]) {
        let type = json["@type"] as? String ?? ""
        if let extra = json["@extra"] as? String {
            let promise = withLock { pending.removeValue(forKey: extra) }
            if let promise = promise {
                if type == "error" {
                    let code = TdlibJson.int(json["code"]) ?? 0
                    let message = json["message"] as? String ?? "TDLib error"
                    promise.fail(TdlibError("tdlib_\(code)", message, TdlibJson.string(json)))
                } else {
                    promise.complete(json)
                }
            }
        }
        switch type {
        case "updateAuthorizationState":
            if let state = json["authorization_state"] as? [String: Any] {
                handleAuthorizationState(state)
            }
        case "authorizationStateReady",
             "authorizationStateWaitPhoneNumber",
             "authorizationStateWaitCode",
             "authorizationStateWaitPassword",
             "authorizationStateWaitTdlibParameters",
             "authorizationStateWaitEncryptionKey",
             "authorizationStateClosed":
            // Bare replies to getAuthorizationState must also drive the state
            // machine, exactly like the Kotlin bridge.
            handleAuthorizationState(json)
        case "updateConnectionState":
            if let state = json["state"] as? [String: Any] {
                handleConnectionState(state)
            }
        case "updateMessageSendSucceeded":
            handleSendSucceeded(json)
        case "updateMessageSendFailed":
            handleSendFailed(json)
        case "updateFile":
            if let file = json["file"] as? [String: Any] {
                handleUpdatedFile(file)
            }
        default:
            break
        }
    }

    private func handleAuthorizationState(_ state: [String: Any]) {
        let newState: String = withLock {
            authorizationState = (state["@type"] as? String) ?? authorizationState
            return authorizationState
        }
        let cfg = withLock { config }
        switch newState {
        case "authorizationStateWaitTdlibParameters":
            if let cfg = cfg {
                sendNoWait([
                    "@type": "setTdlibParameters",
                    "use_test_dc": false,
                    "database_directory": cfg.databaseDirectory,
                    "files_directory": cfg.filesDirectory,
                    // TDLib JSON "bytes" fields are base64 strings; the Dart
                    // side already supplies base64 — pass through verbatim.
                    "database_encryption_key": cfg.encryptionKey,
                    "use_file_database": true,
                    "use_chat_info_database": true,
                    "use_message_database": true,
                    "use_secret_chats": false,
                    "api_id": cfg.apiId,
                    "api_hash": cfg.apiHash,
                    "system_language_code": "en",
                    "device_model": TdlibDeviceInfo.deviceModel,
                    "system_version": TdlibDeviceInfo.systemVersion,
                    "application_version": cfg.applicationVersion,
                ])
            }
        case "authorizationStateWaitEncryptionKey":
            // Legacy state kept for parity; not emitted by TDLib 1.8.x.
            if let cfg = cfg {
                sendNoWait(["@type": "checkDatabaseEncryptionKey", "encryption_key": cfg.encryptionKey])
            }
        default:
            break
        }
        completeAuthorizationWaiters(newState)
        emitEvent(["type": "authorization", "authorizationState": newState])
    }

    private func handleConnectionState(_ state: [String: Any]) {
        let newState: String = withLock {
            connectionState = (state["@type"] as? String) ?? connectionState
            return connectionState
        }
        completeConnectionWaiters(newState)
        emitEvent(["type": "connection", "connectionState": newState])
    }

    // MARK: - State waiters

    func waitForAuthorizationState(_ acceptedStates: Set<String>, timeoutMs: Int) -> Promise<[String: Any]> {
        return waitForAuthorizationStateValue(acceptedStates, timeoutMs: timeoutMs).map { _ in [:] }
    }

    private func waitForAuthorizationStateValue(_ acceptedStates: Set<String>, timeoutMs: Int) -> Promise<String> {
        let promise = Promise<String>()
        let waiter = TdlibAuthorizationWaiter(acceptedStates: acceptedStates, promise: promise)
        let immediate: String? = withLock {
            if acceptedStates.contains(authorizationState) {
                return authorizationState
            }
            authorizationWaiters.append(waiter)
            return nil
        }
        if let immediate = immediate {
            promise.complete(immediate)
            return promise
        }
        scheduleTimeout(afterMs: timeoutMs) { [weak self] in
            guard let self = self else { return }
            let removed: Bool = self.withLock {
                if let index = self.authorizationWaiters.firstIndex(where: { $0 === waiter }) {
                    self.authorizationWaiters.remove(at: index)
                    return true
                }
                return false
            }
            if removed {
                let current = self.withLock { self.authorizationState }
                promise.fail(TdlibError(
                    "tdlib_auth_state_timeout",
                    "Timed out waiting for TDLib authorization state.",
                    "current=\(current) accepted=\(acceptedStates.sorted().joined(separator: ","))"
                ))
            }
        }
        return promise
    }

    private func completeAuthorizationWaiters(_ state: String) {
        let matched: [TdlibAuthorizationWaiter] = withLock {
            let hits = authorizationWaiters.filter { $0.acceptedStates.contains(state) }
            authorizationWaiters.removeAll { waiter in hits.contains(where: { $0 === waiter }) }
            return hits
        }
        matched.forEach { $0.promise.complete(state) }
    }

    func waitForConnectionReady(timeoutMs: Int) -> Promise<String> {
        let promise = Promise<String>()
        let waiter = TdlibConnectionWaiter(acceptedStates: ["connectionStateReady"], promise: promise)
        let immediate: String? = withLock {
            if connectionState == "connectionStateReady" {
                return connectionState
            }
            connectionWaiters.append(waiter)
            return nil
        }
        if let immediate = immediate {
            promise.complete(immediate)
            return promise
        }
        // Nudge TDLib to replay current state (it may have connected before
        // anyone listened).
        sendNoWait(["@type": "getCurrentState"])
        scheduleTimeout(afterMs: timeoutMs) { [weak self] in
            guard let self = self else { return }
            let removed: Bool = self.withLock {
                if let index = self.connectionWaiters.firstIndex(where: { $0 === waiter }) {
                    self.connectionWaiters.remove(at: index)
                    return true
                }
                return false
            }
            if removed {
                let current = self.withLock { self.connectionState }
                promise.fail(TdlibError(
                    "tdlib_connection_timeout",
                    "Timed out waiting for TDLib network connection.",
                    current
                ))
            }
        }
        return promise
    }

    private func completeConnectionWaiters(_ state: String) {
        let matched: [TdlibConnectionWaiter] = withLock {
            let hits = connectionWaiters.filter { $0.acceptedStates.contains(state) }
            connectionWaiters.removeAll { waiter in hits.contains(where: { $0 === waiter }) }
            return hits
        }
        matched.forEach { $0.promise.complete(state) }
    }

    // MARK: - Request plumbing

    func send(_ request: [String: Any]) -> Promise<[String: Any]> {
        ensureClient()
        var payload = request
        let extra = UUID().uuidString
        payload["@extra"] = extra
        let promise = Promise<[String: Any]>()
        let currentClientId: Int32 = withLock {
            pending[extra] = promise
            return clientId
        }
        TdlibJsonClient.send(currentClientId, TdlibJson.string(payload))
        return promise
    }

    func sendNoWait(_ request: [String: Any]) {
        ensureClient()
        let currentClientId = withLock { clientId }
        TdlibJsonClient.send(currentClientId, TdlibJson.string(request))
    }

    func ensureReadyForAuth() throws {
        ensureClient()
    }

    func ensureAuthorized() throws {
        try ensureReadyForAuth()
        let state = withLock { authorizationState }
        if state != "authorizationStateReady" {
            throw TdlibError("tdlib_auth_required", "Local TDLib is not authorized.", state)
        }
    }

    var currentClientIdForCancel: Int32 {
        return withLock { clientId }
    }

    // MARK: - Result shaping

    static func chatResult(_ chat: [String: Any]) -> [String: Any] {
        return [
            "tdlibChatId": NSNumber(value: TdlibJson.int64(chat["id"]) ?? 0),
            "title": (chat["title"] as? String) ?? NSNull(),
            "type": (((chat["type"] as? [String: Any])?["@type"]) as? String) ?? NSNull(),
        ]
    }

    static func messageRef(
        _ message: [String: Any],
        fallbackFilename: String,
        fallbackMime: String?,
        fallbackSize: Int64?
    ) -> [String: Any] {
        let file = extractFile(message)
        let content = message["content"] as? [String: Any]
        let document = content?["document"] as? [String: Any]
        let remote = file?["remote"] as? [String: Any]
        let fileId: Int? = {
            guard let id = TdlibJson.int(file?["id"]), id > 0 else { return nil }
            return id
        }()
        let size: Int64? = {
            if let bytes = TdlibJson.int64(file?["size"]), bytes > 0 { return bytes }
            return fallbackSize
        }()
        let mime = (document?["mime_type"] as? String) ?? fallbackMime
        let filename: String = {
            if let name = document?["file_name"] as? String, !TdlibArgs.isBlank(name) { return name }
            return fallbackFilename
        }()
        return [
            "tdlibChatId": NSNumber(value: TdlibJson.int64(message["chat_id"]) ?? 0),
            "tdlibMessageId": NSNumber(value: TdlibJson.int64(message["id"]) ?? 0),
            "tdlibFileId": fileId.map { NSNumber(value: $0) } ?? NSNull(),
            "tdlibRemoteFileId": (remote?["id"] as? String) ?? NSNull(),
            "sizeBytes": size.map { NSNumber(value: $0) } ?? NSNull(),
            "mimeType": mime ?? NSNull(),
            "filename": filename,
        ]
    }

    static func extractFile(_ message: [String: Any]) -> [String: Any]? {
        guard let content = message["content"] as? [String: Any] else { return nil }
        switch content["@type"] as? String ?? "" {
        case "messageDocument":
            return (content["document"] as? [String: Any])?["document"] as? [String: Any]
        case "messageVideo":
            return (content["video"] as? [String: Any])?["video"] as? [String: Any]
        case "messageAnimation":
            return (content["animation"] as? [String: Any])?["animation"] as? [String: Any]
        case "messageAudio":
            return (content["audio"] as? [String: Any])?["audio"] as? [String: Any]
        case "messageVoiceNote":
            return (content["voice_note"] as? [String: Any])?["voice"] as? [String: Any]
        case "messagePhoto":
            return largestPhotoFile((content["photo"] as? [String: Any])?["sizes"] as? [Any])
        default:
            return nil
        }
    }

    static func largestPhotoFile(_ sizes: [Any]?) -> [String: Any]? {
        guard let sizes = sizes else { return nil }
        var best: [String: Any]?
        var bestArea = -1
        for case let size as [String: Any] in sizes {
            let area = (TdlibJson.int(size["width"]) ?? 0) * (TdlibJson.int(size["height"]) ?? 0)
            if area > bestArea {
                bestArea = area
                best = size["photo"] as? [String: Any]
            }
        }
        return best
    }

    static func isFinalMessage(_ message: [String: Any]) -> Bool {
        return (TdlibJson.int64(message["id"]) ?? 0) > 0 && message["sending_state"] == nil
    }

    static func channelIdFromPeer(_ peerId: Int64?) -> Int64? {
        guard let peerId = peerId, peerId != 0 else { return nil }
        let text = String(abs(peerId))
        if text.hasPrefix("100") && text.count > 3 {
            return Int64(text.dropFirst(3))
        }
        return abs(peerId)
    }

    // MARK: - Event sink

    func emitEvent(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }

    func emitError(_ code: String, _ message: String) {
        emitEvent(["type": "error", "code": code, "message": message])
    }
}

extension TdlibBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
