package com.example.flutter_m_fsdk

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File

internal class GalleryMediaQuery(private val context: Context) {
    fun listGalleryMedia(args: Map<String, Any?>): List<Map<String, Any?>> {
        val limit = ((args["limit"] as? Number)?.toInt() ?: 100).coerceIn(1, 500)
        val includeImages = args["includeImages"] as? Boolean ?: true
        val includeVideos = args["includeVideos"] as? Boolean ?: true
        val strategy = args["strategy"] as? String ?: "media_store_only"
        val items = mutableListOf<Map<String, Any?>>()
        if (strategy != "file_path_only") {
            if (includeImages) {
                items.addAll(queryMediaCollection(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image", limit))
            }
            if (includeVideos) {
                items.addAll(queryMediaCollection(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "video", limit))
            }
        }
        if (strategy == "file_path_only" || strategy == "media_store_and_file_path") {
            items.addAll(queryPublicMediaPaths(includeImages, includeVideos, limit))
        }
        return items
            .sortedByDescending {
                maxOf(
                    it["modifiedAtMillis"] as? Long ?: 0L,
                    it["addedAtMillis"] as? Long ?: 0L,
                )
            }
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

        val sortOrder =
            "CASE WHEN ${MediaStore.MediaColumns.DATE_MODIFIED} > ${MediaStore.MediaColumns.DATE_ADDED} " +
                "THEN ${MediaStore.MediaColumns.DATE_MODIFIED} ELSE ${MediaStore.MediaColumns.DATE_ADDED} END DESC"
        val out = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(collection, projection.toTypedArray(), null, null, sortOrder)?.use { cursor ->
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
                val addedSeconds = longAt(cursor, addedColumn) ?: modifiedSeconds
                out.add(
                    mapOf(
                        "id" to "$mediaType:$id",
                        "contentUri" to uri.toString(),
                        "sourceKind" to "mediastore",
                        "path" to stringAt(cursor, dataColumn),
                        "name" to name,
                        "sizeBytes" to size,
                        "mimeType" to (stringAt(cursor, mimeColumn) ?: if (mediaType == "video") "video/mp4" else "image/jpeg"),
                        "mediaType" to mediaType,
                        "relativePath" to stringAt(cursor, relativeColumn),
                        "modifiedAtMillis" to modifiedSeconds * 1000L,
                        "addedAtMillis" to addedSeconds * 1000L,
                        "durationMs" to longAt(cursor, durationColumn),
                    )
                )
            }
        }
        return out
    }

    private fun queryPublicMediaPaths(includeImages: Boolean, includeVideos: Boolean, limit: Int): List<Map<String, Any?>> {
        val roots = mutableListOf<File>()
        if (includeImages) {
            roots.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM))
            roots.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES))
        }
        if (includeVideos) {
            roots.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES))
        }
        val out = mutableListOf<Map<String, Any?>>()
        for (root in roots.distinctBy { it.absolutePath }) {
            if (!root.exists() || !root.canRead()) continue
            scanPathRoot(root, includeImages, includeVideos, limit, out)
            if (out.size >= limit) break
        }
        return out
    }

    private fun scanPathRoot(
        root: File,
        includeImages: Boolean,
        includeVideos: Boolean,
        limit: Int,
        out: MutableList<Map<String, Any?>>
    ) {
        val pending = ArrayDeque<File>()
        pending.add(root)
        while (pending.isNotEmpty() && out.size < limit) {
            val current = pending.removeFirst()
            val children = try {
                current.listFiles()
            } catch (_: SecurityException) {
                null
            } ?: continue
            for (child in children) {
                if (out.size >= limit) break
                if (child.isDirectory) {
                    pending.add(child)
                    continue
                }
                if (!child.isFile || child.length() <= 0L) continue
                val mediaType = mediaTypeForPath(child)
                if (mediaType == "image" && !includeImages) continue
                if (mediaType == "video" && !includeVideos) continue
                if (mediaType == null) continue
                val mimeType = mimeTypeForPath(child, mediaType)
                out.add(
                    mapOf(
                        "id" to "path:${child.absolutePath.hashCode()}",
                        "contentUri" to child.toURI().toString(),
                        "sourceKind" to "path",
                        "path" to child.absolutePath,
                        "name" to child.name,
                        "sizeBytes" to child.length(),
                        "mimeType" to mimeType,
                        "mediaType" to mediaType,
                        "relativePath" to child.parentFile?.absolutePath,
                        "modifiedAtMillis" to child.lastModified(),
                        "addedAtMillis" to child.lastModified(),
                        "durationMs" to null,
                    )
                )
            }
        }
    }

    private fun mediaTypeForPath(file: File): String? {
        val name = file.name.lowercase()
        return when {
            name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png") || name.endsWith(".webp") || name.endsWith(".gif") || name.endsWith(".heic") || name.endsWith(".heif") -> "image"
            name.endsWith(".mp4") || name.endsWith(".mov") || name.endsWith(".m4v") || name.endsWith(".webm") || name.endsWith(".mkv") || name.endsWith(".3gp") -> "video"
            else -> null
        }
    }

    private fun mimeTypeForPath(file: File, mediaType: String): String {
        val name = file.name.lowercase()
        return when {
            name.endsWith(".png") -> "image/png"
            name.endsWith(".webp") -> "image/webp"
            name.endsWith(".gif") -> "image/gif"
            name.endsWith(".heic") -> "image/heic"
            name.endsWith(".heif") -> "image/heif"
            name.endsWith(".mov") -> "video/quicktime"
            name.endsWith(".webm") -> "video/webm"
            name.endsWith(".mkv") -> "video/x-matroska"
            mediaType == "video" -> "video/mp4"
            else -> "image/jpeg"
        }
    }

    private fun displayNameFor(uri: Uri): String? {
        return context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) stringAt(cursor, cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)) else null
        }
    }
}

internal fun stringAt(cursor: android.database.Cursor, index: Int): String? {
    if (index < 0 || cursor.isNull(index)) return null
    return cursor.getString(index)
}

internal fun longAt(cursor: android.database.Cursor, index: Int): Long? {
    if (index < 0 || cursor.isNull(index)) return null
    return cursor.getLong(index)
}
