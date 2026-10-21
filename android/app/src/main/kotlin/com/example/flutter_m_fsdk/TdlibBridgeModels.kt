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
    val cancellation: CompletableFuture<Unit> = CompletableFuture(),
    @Volatile var cancelPendingUpload: (() -> Unit)? = null,
    val uploadChatId: Long? = null,
    val deletedMessageIds: MutableSet<Long> = mutableSetOf(),
    @Volatile var onUploadDeleted: (() -> Unit)? = null,
    /// Monotonic time of the last upload byte progress; drives the idle
    /// watchdog so a slow but advancing upload is never cut off.
    @Volatile var lastActivityAtMs: Long = android.os.SystemClock.elapsedRealtime(),
)

internal data class DownloadWaiter(
    val transferId: String,
    val destinationPath: String,
    val future: CompletableFuture<Map<String, Any?>>,
) {
    /// Set once TDLib reports the file actively downloading. A later inactive,
    /// incomplete update means TDLib gave up and the waiter fails immediately.
    @Volatile var observedActive: Boolean = false
}

internal data class AuthorizationWaiter(
    val acceptedStates: Set<String>,
    val future: CompletableFuture<String>,
)

internal data class ConnectionWaiter(
    val acceptedStates: Set<String>,
    val future: CompletableFuture<String>,
)
