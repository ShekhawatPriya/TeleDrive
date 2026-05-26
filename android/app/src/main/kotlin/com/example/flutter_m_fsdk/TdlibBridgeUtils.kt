package com.example.flutter_m_fsdk

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.CompletableFuture

internal fun jsonToMap(json: JSONObject): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val keys = json.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val value = json.get(key)
        map[key] = when (value) {
            JSONObject.NULL -> null
            is JSONObject -> jsonToMap(value)
            is JSONArray -> jsonArrayToList(value)
            else -> value
        }
    }
    return map
}

internal fun jsonArrayToList(array: JSONArray): List<Any?> {
    val list = mutableListOf<Any?>()
    for (index in 0 until array.length()) {
        val value = array.get(index)
        list.add(
            when (value) {
                JSONObject.NULL -> null
                is JSONObject -> jsonToMap(value)
                is JSONArray -> jsonArrayToList(value)
                else -> value
            }
        )
    }
    return list
}

internal fun tdlibAppVersion(context: Context): String {
    return try {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        info.versionName ?: "1.0"
    } catch (_: Throwable) {
        "1.0"
    }
}

internal fun requireString(args: Map<String, Any?>, key: String): String {
    return stringArg(args, key)?.takeIf { it.isNotBlank() }
        ?: throw TdlibException("tdlib_argument_missing", "$key is required.")
}

internal fun stringArg(args: Map<String, Any?>, key: String): String? = args[key] as? String

internal fun intArg(args: Map<String, Any?>, key: String): Int? = when (val value = args[key]) {
    is Int -> value
    is Long -> value.toInt()
    is Number -> value.toInt()
    is String -> value.toIntOrNull()
    else -> null
}

internal fun longArg(args: Map<String, Any?>, key: String): Long? = when (val value = args[key]) {
    is Long -> value
    is Int -> value.toLong()
    is Number -> value.toLong()
    is String -> value.toLongOrNull()
    else -> null
}

internal fun <T> failed(error: Throwable): CompletableFuture<T> {
    val future = CompletableFuture<T>()
    future.completeExceptionally(error)
    return future
}

class TdlibException(
    val code: String,
    override val message: String,
    val detailsText: String? = null,
) : RuntimeException(message)
