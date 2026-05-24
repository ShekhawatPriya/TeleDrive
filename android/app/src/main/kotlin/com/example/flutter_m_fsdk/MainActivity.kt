package com.example.flutter_m_fsdk

import android.content.ContentUris
import android.net.Uri
import android.graphics.Bitmap
import android.media.ThumbnailUtils
import android.os.Build
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

class MainActivity : FlutterActivity() {
    private val channelName = "teledrive/tdlib"
    private val eventsName = "teledrive/tdlib/events"
    private val mediaChannelName = "teledrive/media"
    private lateinit var tdlibBridge: TdlibBridge

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
        try {
            when (call.method) {
                "createVideoThumbnail" -> result.success(createVideoThumbnail(typedArgs))
                "listGalleryMedia" -> result.success(listGalleryMedia(typedArgs))
                "copyContentUriToFile" -> result.success(copyContentUriToFile(typedArgs))
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("media_thumbnail_failed", error.message ?: "Media thumbnail failed.", null)
        }
    }

    private fun createVideoThumbnail(args: Map<String, Any?>): Map<String, Any?> {
        val sourcePath = args["sourcePath"] as? String
            ?: throw IllegalArgumentException("sourcePath is required")
        val destinationPath = args["destinationPath"] as? String
            ?: throw IllegalArgumentException("destinationPath is required")
        val maxEdge = ((args["maxEdge"] as? Number)?.toInt() ?: 360).coerceAtLeast(1)
        val source = File(sourcePath)
        if (!source.exists()) throw IllegalArgumentException("Video file does not exist")
        val raw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ThumbnailUtils.createVideoThumbnail(source, Size(maxEdge, maxEdge), null)
        } else {
            @Suppress("DEPRECATION")
            ThumbnailUtils.createVideoThumbnail(sourcePath, MediaStore.Images.Thumbnails.MINI_KIND)
        } ?: throw IllegalStateException("Could not create video thumbnail")
        val bitmap = scaleBitmapToMaxEdge(raw, maxEdge)
        if (bitmap !== raw) raw.recycle()
        val outFile = File(destinationPath)
        outFile.parentFile?.mkdirs()
        FileOutputStream(outFile).use { stream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 82, stream)
        }
        val width = bitmap.width
        val height = bitmap.height
        bitmap.recycle()
        return mapOf(
            "path" to outFile.absolutePath,
            "width" to width,
            "height" to height,
            "sizeBytes" to outFile.length(),
        )
    }

    private fun scaleBitmapToMaxEdge(source: Bitmap, maxEdge: Int): Bitmap {
        val largest = maxOf(source.width, source.height)
        if (largest <= maxEdge) return source
        val ratio = maxEdge.toDouble() / largest.toDouble()
        val width = maxOf(1, (source.width * ratio).toInt())
        val height = maxOf(1, (source.height * ratio).toInt())
        return Bitmap.createScaledBitmap(source, width, height, true)
    }

    private fun listGalleryMedia(args: Map<String, Any?>): List<Map<String, Any?>> {
        val limit = ((args["limit"] as? Number)?.toInt() ?: 100).coerceIn(1, 500)
        val includeImages = args["includeImages"] as? Boolean ?: true
        val includeVideos = args["includeVideos"] as? Boolean ?: true
        val items = mutableListOf<Map<String, Any?>>()
        if (includeImages) {
            items.addAll(queryMediaCollection(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image", limit))
        }
        if (includeVideos) {
            items.addAll(queryMediaCollection(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "video", limit))
        }
        return items
            .sortedByDescending { it["modifiedAtMillis"] as? Long ?: 0L }
            .take(limit)
    }

    private fun queryMediaCollection(collection: Uri, mediaType: String, limit: Int): List<Map<String, Any?>> {
        val projection = mutableListOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.RELATIVE_PATH,
        )
        @Suppress("DEPRECATION")
        projection.add(MediaStore.MediaColumns.DATA)
        if (mediaType == "video") projection.add(MediaStore.Video.Media.DURATION)

        val sortOrder = "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"
        val out = mutableListOf<Map<String, Any?>>()
        contentResolver.query(collection, projection.toTypedArray(), null, null, sortOrder)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
            val mimeColumn = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
            val modifiedColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_MODIFIED)
            val addedColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED)
            val relativeColumn = cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
            @Suppress("DEPRECATION")
            val dataColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            val durationColumn = if (mediaType == "video") cursor.getColumnIndex(MediaStore.Video.Media.DURATION) else -1
            while (cursor.moveToNext() && out.size < limit) {
                val id = cursor.getLong(idColumn)
                val uri = ContentUris.withAppendedId(collection, id)
                val name = stringAt(cursor, nameColumn) ?: displayNameFor(uri) ?: "$mediaType-$id"
                val size = longAt(cursor, sizeColumn) ?: 0L
                if (size <= 0L) continue
                val modifiedSeconds = longAt(cursor, modifiedColumn) ?: longAt(cursor, addedColumn) ?: 0L
                out.add(
                    mapOf(
                        "id" to "$mediaType:$id",
                        "contentUri" to uri.toString(),
                        "path" to stringAt(cursor, dataColumn),
                        "name" to name,
                        "sizeBytes" to size,
                        "mimeType" to (stringAt(cursor, mimeColumn) ?: if (mediaType == "video") "video/mp4" else "image/jpeg"),
                        "mediaType" to mediaType,
                        "relativePath" to stringAt(cursor, relativeColumn),
                        "modifiedAtMillis" to modifiedSeconds * 1000L,
                        "durationMs" to longAt(cursor, durationColumn),
                    )
                )
            }
        }
        return out
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

    private fun stringAt(cursor: android.database.Cursor, index: Int): String? {
        if (index < 0 || cursor.isNull(index)) return null
        return cursor.getString(index)
    }

    private fun longAt(cursor: android.database.Cursor, index: Int): Long? {
        if (index < 0 || cursor.isNull(index)) return null
        return cursor.getLong(index)
    }

    private fun displayNameFor(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) stringAt(cursor, cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)) else null
        }
    }
}
