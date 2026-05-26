package com.example.flutter_m_fsdk

import android.content.ContentUris
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.media.ThumbnailUtils
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "teledrive/tdlib"
    private val eventsName = "teledrive/tdlib/events"
    private val mediaChannelName = "teledrive/media"
    private val deleteRequestCode = 7114
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeleteUris: List<Uri> = emptyList()
    private lateinit var tdlibBridge: TdlibBridge
    private val galleryMediaQuery by lazy { GalleryMediaQuery(this) }
    private val mediaDerivatives by lazy { MediaDerivativeGenerator(this) }
    private val derivativeExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "teledrive-media-derivative").apply { isDaemon = true }
    }
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "teledrive-media-io").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tdlibBridge = TdlibBridge(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleTdlibCall(call, result) }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsName)
            .setStreamHandler(tdlibBridge)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, result -> handleMediaCall(call, result) }
    }

    private fun handleTdlibCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val typedArgs = args.entries.associate { "${it.key}" to it.value }
        try {
            when (call.method) {
                "isAvailable" -> result.success(tdlibBridge.isAvailable())
                "configure" -> complete(tdlibBridge.configure(typedArgs), result)
                "health" -> result.success(tdlibBridge.health())
                "getMe" -> complete(tdlibBridge.getMe(), result)
                "setPhoneNumber" -> complete(tdlibBridge.setPhoneNumber(typedArgs), result)
                "checkCode" -> complete(tdlibBridge.checkCode(typedArgs), result)
                "checkPassword" -> complete(tdlibBridge.checkPassword(typedArgs), result)
                "resendCode" -> complete(tdlibBridge.resendCode(), result)
                "resolveChat" -> complete(tdlibBridge.resolveChat(typedArgs), result)
                "sendDocument" -> complete(tdlibBridge.sendDocument(typedArgs), result)
                "downloadToFile" -> complete(tdlibBridge.downloadToFile(typedArgs), result)
                "cancelTransfer" -> complete(tdlibBridge.cancelTransfer(typedArgs), result)
                else -> result.notImplemented()
            }
        } catch (error: TdlibException) {
            result.error(error.code, error.message, error.detailsText)
        } catch (error: Throwable) {
            result.error("tdlib_error", error.message ?: "TDLib bridge failed.", null)
        }
    }

    private fun complete(future: CompletableFuture<Map<String, Any?>>, result: MethodChannel.Result) {
        future.whenComplete { value, error ->
            runOnUiThread {
                val cause = error?.cause ?: error
                when (cause) {
                    null -> result.success(value)
                    is TdlibException -> result.error(cause.code, cause.message, cause.detailsText)
                    else -> result.error("tdlib_error", cause.message ?: "TDLib bridge failed.", null)
                }
            }
        }
    }

    private fun handleMediaCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val typedArgs = args.entries.associate { "${it.key}" to it.value }
        when (call.method) {
            "createImageDerivative" -> runMediaTask(derivativeExecutor, result) { mediaDerivatives.createImageDerivative(typedArgs) }
            "createVideoThumbnail" -> runMediaTask(derivativeExecutor, result) { mediaDerivatives.createVideoThumbnail(typedArgs) }
            "listGalleryMedia" -> runMediaTask(ioExecutor, result) { galleryMediaQuery.listGalleryMedia(typedArgs) }
            "copyContentUriToFile" -> runMediaTask(ioExecutor, result) { copyContentUriToFile(typedArgs) }
            "deleteGalleryMedia" -> deleteGalleryMedia(typedArgs, result)
            else -> result.notImplemented()
        }
    }

    private inline fun runMediaTask(
        executor: ExecutorService,
        result: MethodChannel.Result,
        crossinline block: () -> Any?,
    ) {
        executor.execute {
            try {
                Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            } catch (_: Throwable) {
            }
            val outcome: Result<Any?> = try {
                Result.success(block())
            } catch (t: Throwable) {
                Result.failure(t)
            }
            mainHandler.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { error ->
                        result.error(
                            "media_derivative_failed",
                            error.message ?: "Media derivative failed.",
                            null,
                        )
                    },
                )
            }
        }
    }

    override fun onDestroy() {
        derivativeExecutor.shutdown()
        ioExecutor.shutdown()
        super.onDestroy()
    }

    private fun deleteGalleryMedia(args: Map<String, Any?>, result: MethodChannel.Result) {
        if (pendingDeleteResult != null) {
            result.error("media_delete_pending", "A media deletion request is already open.", null)
            return
        }
        val rawUris = args["contentUris"] as? List<*> ?: emptyList<Any?>()
        val uris = rawUris
            .mapNotNull { parseDeleteUri(it as? String) }
            .distinctBy { it.toString() }
        if (uris.isEmpty()) {
            result.success(deleteResultMap(emptyList(), emptyList(), emptyList(), false))
            return
        }
        try {
            val request = MediaStore.createDeleteRequest(contentResolver, uris)
            pendingDeleteResult = result
            pendingDeleteUris = uris
            startIntentSenderForResult(
                request.intentSender,
                deleteRequestCode,
                null,
                0,
                0,
                0,
                null,
            )
        } catch (error: IntentSender.SendIntentException) {
            clearPendingDelete()
            result.error("media_delete_launch_failed", error.message ?: "Could not open Android confirmation.", null)
        } catch (error: Throwable) {
            clearPendingDelete()
            result.error("media_delete_failed", error.message ?: "Could not request media deletion.", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != deleteRequestCode) return
        val result = pendingDeleteResult ?: return
        val uris = pendingDeleteUris
        try {
            if (resultCode != RESULT_OK) {
                result.success(deleteResultMap(uris, emptyList(), uris, true))
                return
            }
            val deleted = uris.filter { !uriExists(it) }
            val failed = uris.filter { uriExists(it) }
            result.success(deleteResultMap(uris, deleted, failed, false))
        } finally {
            clearPendingDelete()
        }
    }

    private fun parseDeleteUri(value: String?): Uri? {
        val raw = value?.trim()
        if (raw.isNullOrEmpty()) return null
        val uri = try {
            Uri.parse(raw)
        } catch (_: Throwable) {
            return null
        }
        if (uri.scheme != "content") return null
        if (uri.authority != MediaStore.AUTHORITY) return null
        val segments = uri.pathSegments ?: return null
        if (segments.size < 4) return null
        val isImageItem = segments.contains("images") && segments.contains("media")
        val isVideoItem = segments.contains("video") && segments.contains("media")
        if (!isImageItem && !isVideoItem) return null
        if (segments.lastOrNull()?.toLongOrNull() == null) return null
        return uri
    }

    private fun uriExists(uri: Uri): Boolean {
        return try {
            contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns._ID),
                null,
                null,
                null,
            )?.use { cursor -> cursor.moveToFirst() } ?: false
        } catch (_: SecurityException) {
            true
        } catch (_: Throwable) {
            true
        }
    }

    private fun deleteResultMap(
        requested: List<Uri>,
        deleted: List<Uri>,
        failed: List<Uri>,
        userCancelled: Boolean,
    ): Map<String, Any?> {
        return mapOf(
            "requested" to requested.size,
            "deleted" to deleted.size,
            "failed" to failed.size,
            "userCancelled" to userCancelled,
            "deletedUris" to deleted.map { it.toString() },
            "failedUris" to failed.map { it.toString() },
        )
    }

    private fun clearPendingDelete() {
        pendingDeleteResult = null
        pendingDeleteUris = emptyList()
    }

    private fun copyContentUriToFile(args: Map<String, Any?>): Map<String, Any?> {
        val contentUri = args["contentUri"] as? String
            ?: throw IllegalArgumentException("contentUri is required")
        val destinationPath = args["destinationPath"] as? String
            ?: throw IllegalArgumentException("destinationPath is required")
        val uri = Uri.parse(contentUri)
        val outFile = File(destinationPath)
        outFile.parentFile?.mkdirs()
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("Could not open media item")
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        }
        return mapOf("path" to outFile.absolutePath, "sizeBytes" to outFile.length())
    }


    private fun displayNameFor(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) stringAt(cursor, cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)) else null
        }
    }
}


