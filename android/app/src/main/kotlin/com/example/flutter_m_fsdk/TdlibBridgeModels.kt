package com.example.flutter_m_fsdk

import java.util.concurrent.CompletableFuture

internal data class Config(
    val databaseDirectory: String,
    val filesDirectory: String,
    val apiId: Int,
    val apiHash: String,
    val encryptionKey: String,
    val expectedTelegramUserId: Long,
    val applicationVersion: String,
)

internal data class Transfer(
    val transferId: String,
    @Volatile var fileId: Int? = null,
    @Volatile var cancelled: Boolean = false,
)

internal data class DownloadWaiter(
    val transferId: String,
    val destinationPath: String,
    val future: CompletableFuture<Map<String, Any?>>,
)

internal data class AuthorizationWaiter(
    val acceptedStates: Set<String>,
    val future: CompletableFuture<String>,
)

internal data class ConnectionWaiter(
    val acceptedStates: Set<String>,
    val future: CompletableFuture<String>,
)
