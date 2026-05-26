package com.example.flutter_m_fsdk

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import java.io.File
import java.io.FileOutputStream

internal class MediaDerivativeGenerator(private val context: Context) {
    fun createImageDerivative(args: Map<String, Any?>): Map<String, Any?> {
        val sourcePath = args["sourcePath"] as? String
            ?: throw IllegalArgumentException("sourcePath is required")
        val destinationPath = args["destinationPath"] as? String
            ?: throw IllegalArgumentException("destinationPath is required")
        val maxEdge = ((args["maxEdge"] as? Number)?.toInt() ?: 360).coerceAtLeast(1)
        val quality = ((args["quality"] as? Number)?.toInt() ?: 82).coerceIn(1, 100)
        val source = File(sourcePath)
        if (!source.exists()) throw IllegalArgumentException("Image file does not exist")
        val decoded = ImageDecoder.decodeBitmap(ImageDecoder.createSource(source)) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val largest = maxOf(info.size.width, info.size.height)
            if (largest > maxEdge) {
                val ratio = maxEdge.toDouble() / largest.toDouble()
                val width = maxOf(1, (info.size.width * ratio).toInt())
                val height = maxOf(1, (info.size.height * ratio).toInt())
                decoder.setTargetSize(width, height)
            }
        }
        val bitmap = scaleBitmapToMaxEdge(decoded, maxEdge)
        if (bitmap !== decoded) decoded.recycle()
        val outFile = File(destinationPath)
        outFile.parentFile?.mkdirs()
        FileOutputStream(outFile).use { stream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
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

    fun createVideoThumbnail(args: Map<String, Any?>): Map<String, Any?> {
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
}
