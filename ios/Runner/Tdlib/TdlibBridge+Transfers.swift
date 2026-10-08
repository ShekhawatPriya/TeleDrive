import Foundation

/// Upload/download/cancel — port of the transfer half of TdlibBridge.kt.
extension TdlibBridge {
    // MARK: - Upload

    func sendDocument(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        try ensureAuthorized()
        let transferId = try TdlibArgs.requireString(args, "transferId")
        guard let chatId = TdlibArgs.int64(args, "chatId") else {
            throw TdlibError("tdlib_target_unresolved", "TDLib chat id is required.")
        }
        let filePath = try TdlibArgs.requireString(args, "filePath")
        let filename = TdlibArgs.string(args, "filename") ?? (filePath as NSString).lastPathComponent
        let mimeType = TdlibArgs.string(args, "mimeType")
        let sizeBytes = TdlibArgs.int64(args, "sizeBytes")
        let transfer = TdlibTransfer(transferId: transferId, uploadChatId: chatId)
        withLock { transfers[transferId] = transfer }
        emitProgress(transferId, "uploading", 0, sizeBytes, nil)

        let inputContent: [String: Any] = [
            "@type": "inputMessageDocument",
            "document": ["@type": "inputFileLocal", "path": filePath] as [String: Any],
            "disable_content_type_detection": false,
            "caption": [
                "@type": "formattedText",
                "text": "",
                "entities": [Any](),
            ] as [String: Any],
        ]
        let request: [String: Any] = [
            "@type": "sendMessage",
            "chat_id": NSNumber(value: chatId),
            "input_message_content": inputContent,
        ]

        let ready = Promise<String>()
        let settleReadiness: (Result<String, Error>) -> Void = { result in
            switch result {
            case .success(let state): ready.complete(state)
            case .failure(let error): ready.fail(error)
            }
        }
        waitForConnectionReady(timeoutMs: 45000).onComplete(settleReadiness)
        transfer.cancellation.onComplete(settleReadiness)
        let operation = ready
            .then { _ in
                self.sendTransferIfActive(transferId, request, expectedTransfer: transfer)
            }
            .then { message -> Promise<[String: Any]> in
                self.withLock {
                    if let file = TdlibBridge.extractFile(message),
                       let fileId = TdlibJson.int(file["id"]), fileId > 0 {
                        transfer.fileId = fileId
                    }
                }
                if TdlibBridge.isFinalMessage(message) {
                    return Promise.value(message)
                }
                let oldId = TdlibJson.int64(message["id"]) ?? 0
                self.emitProgress(transferId, "waitingForFinalMessage", 0, sizeBytes, nil)
                return self.waitForCancellableFinalMessage(chatId, oldId, transfer, sizeBytes)
            }
            .map { finalMessage -> [String: Any] in
                // Final success can beat cancellation. Return it for Flutter's
                // durable commit queue instead of orphaning the original.
                let ref = TdlibBridge.messageRef(
                    finalMessage,
                    fallbackFilename: filename,
                    fallbackMime: mimeType,
                    fallbackSize: sizeBytes
                )
                self.emitProgress(transferId, "completed", sizeBytes ?? 0, sizeBytes, nil)
                return ref
            }
        operation.onComplete { _ in
            self.withLock {
                transfer.cancelPendingUpload = nil
                transfer.onUploadDeleted = nil
                if self.transfers[transferId] === transfer {
                    self.transfers.removeValue(forKey: transferId)
                }
            }
        }
        return operation
    }

    private func waitForCancellableFinalMessage(
        _ chatId: Int64, _ messageId: Int64, _ transfer: TdlibTransfer, _ sizeBytes: Int64?
    ) -> Promise<[String: Any]> {
        let key = "\(chatId):\(messageId)"
        let finalMessage = waitForFinalMessage(key, transfer.transferId, sizeBytes)
        let result = Promise<[String: Any]>()
        var deletionRequested = false
        var deletionSucceeded: Bool?
        var verificationStarted = false
        var settled = false
        var finalOutcome: Result<[String: Any], Error>?
        let completeOutcome: (Result<[String: Any], Error>) -> Void = { outcome in
            switch outcome {
            case .success(let message): result.complete(message)
            case .failure(let error): result.fail(error)
            }
        }
        let completeCancelled = {
            let cancelled = TdlibError("tdlib_cancelled", "Transfer was cancelled.")
            _ = self.removeSendWaiter(key, ifSame: finalMessage)
            finalMessage.fail(cancelled)
            result.fail(cancelled)
        }
        func maybeFinish() {
            var cancelled = false
            var complete: Result<[String: Any], Error>?
            var verify: [String: Any]?
            self.withLock {
                if settled { return }
                cancelled = transfer.deletedMessageIds.contains(messageId)
                if case .success(let message)? = finalOutcome,
                   let finalId = TdlibJson.int64(message["id"]) {
                    cancelled = cancelled || transfer.deletedMessageIds.contains(finalId)
                }
                if cancelled {
                    settled = true
                } else if let outcome = finalOutcome {
                    if case .failure = outcome {
                        settled = true
                        complete = outcome
                    } else if !deletionRequested || deletionSucceeded == false {
                        settled = true
                        complete = outcome
                    } else if deletionSucceeded == true && !verificationStarted,
                              case .success(let message) = outcome {
                        verificationStarted = true
                        verify = message
                    }
                }
            }
            if cancelled { completeCancelled() }
            if let complete = complete { completeOutcome(complete) }
            if let message = verify {
                let finalId = TdlibJson.int64(message["id"]) ?? 0
                let finishVerification: (Error?) -> Void = { error in
                    let completion: (Bool, Bool) = self.withLock {
                        if settled { return (false, false) }
                        settled = true
                        return (true, transfer.deletedMessageIds.contains(messageId) || transfer.deletedMessageIds.contains(finalId))
                    }
                    if !completion.0 { return }
                    var missing = completion.1
                    if let tdlibError = error as? TdlibError, tdlibError.code == "tdlib_404" {
                        missing = true
                    }
                    if missing { completeCancelled() } else { completeOutcome(.success(message)) }
                }
                self.send([
                    "@type": "getMessage",
                    "chat_id": NSNumber(value: chatId),
                    "message_id": NSNumber(value: finalId),
                ]).onComplete { checked in
                    if case .failure(let error) = checked { finishVerification(error) }
                    else { finishVerification(nil) }
                }
                self.scheduleTimeout(afterMs: 5000) { finishVerification(nil) }
            }
        }
        withLock { transfer.onUploadDeleted = { maybeFinish() } }
        finalMessage.onComplete { outcome in
            self.withLock { finalOutcome = outcome }
            maybeFinish()
        }
        let cancelPendingUpload = {
            let shouldDelete = self.withLock {
                if deletionRequested || settled { return false }
                deletionRequested = true
                return true
            }
            if !shouldDelete { return }
            // Cancelling a sendMessage upload uses the temporary message id;
            // the pinned TDLib API has no cancelUploadFile method.
            self.send([
                "@type": "deleteMessages",
                "chat_id": NSNumber(value: chatId),
                "message_ids": [NSNumber(value: messageId)],
                "revoke": true,
            ]).onComplete { deletion in
                let deleted: Bool
                if case .success = deletion { deleted = true } else { deleted = false }
                self.withLock { deletionSucceeded = deleted }
                maybeFinish()
            }
        }
        let cancelled = withLock {
            transfer.cancelPendingUpload = cancelPendingUpload
            return transfer.cancelled
        }
        if cancelled { cancelPendingUpload() }
        maybeFinish()
        return result
    }

    func handleDeletedMessages(_ update: [String: Any]) {
        guard TdlibJson.bool(update["is_permanent"]) == true,
              TdlibJson.bool(update["from_cache"]) != true,
              let chatId = TdlibJson.int64(update["chat_id"]),
              let values = update["message_ids"] as? [Any] else { return }
        let ids = values.compactMap { TdlibJson.int64($0) }
        let callbacks: [() -> Void] = withLock {
            transfers.values.filter { $0.uploadChatId == chatId }.compactMap { transfer in
                for id in ids where transfer.deletedMessageIds.count < 256 {
                    transfer.deletedMessageIds.insert(id)
                }
                return transfer.onUploadDeleted
            }
        }
        callbacks.forEach { $0() }
    }

    /// Waits for updateMessageSendSucceeded/Failed keyed by "<chatId>:<oldMessageId>",
    /// consulting the short-lived caches in case the update raced ahead.
    func waitForFinalMessage(_ key: String, _ transferId: String, _ sizeBytes: Int64?) -> Promise<[String: Any]> {
        if let cached = withLock({ completedSends.removeValue(forKey: key) }) {
            return Promise.value(cached)
        }
        if let cachedError = withLock({ failedSends.removeValue(forKey: key) }) {
            return Promise.error(cachedError)
        }

        let waiter = Promise<[String: Any]>()
        withLock { sendWaiters[key] = waiter }

        // Re-check: the final update may have landed between the cache reads
        // and the waiter registration.
        if let cached = withLock({ completedSends.removeValue(forKey: key) }) {
            if removeSendWaiter(key, ifSame: waiter) {
                waiter.complete(cached)
            }
        }
        if let cachedError = withLock({ failedSends.removeValue(forKey: key) }) {
            if removeSendWaiter(key, ifSame: waiter) {
                waiter.fail(cachedError)
            }
        }

        let timeoutMs = uploadTimeoutMs(sizeBytes)
        scheduleTimeout(afterMs: timeoutMs) { [weak self] in
            guard let self = self else { return }
            if self.removeSendWaiter(key, ifSame: waiter) {
                self.withLock { _ = self.transfers.removeValue(forKey: transferId) }
                self.emitProgress(transferId, "failed", 0, sizeBytes, "Timed out waiting for Telegram to confirm the upload.")
                waiter.fail(TdlibError(
                    "tdlib_send_timeout",
                    "Timed out waiting for Telegram to confirm the upload.",
                    "key=\(key) timeoutMs=\(timeoutMs)"
                ))
            }
        }

        return waiter
    }

    private func removeSendWaiter(_ key: String, ifSame waiter: Promise<[String: Any]>) -> Bool {
        return withLock {
            guard sendWaiters[key] === waiter else { return false }
            sendWaiters.removeValue(forKey: key)
            return true
        }
    }

    func handleSendSucceeded(_ update: [String: Any]) {
        guard let message = update["message"] as? [String: Any] else { return }
        let oldId = TdlibJson.int64(update["old_message_id"]) ?? 0
        let chatId = TdlibJson.int64(message["chat_id"]) ?? 0
        let key = "\(chatId):\(oldId)"
        let waiter = withLock { sendWaiters.removeValue(forKey: key) }
        if let waiter = waiter {
            waiter.complete(message)
        } else {
            cacheCompletedSend(key, message)
        }
    }

    func handleSendFailed(_ update: [String: Any]) {
        let message = update["message"] as? [String: Any]
        let oldId = TdlibJson.int64(update["old_message_id"]) ?? 0
        let chatId = TdlibJson.int64(message?["chat_id"]) ?? 0
        let key = "\(chatId):\(oldId)"
        let error = TdlibError(
            "tdlib_send_failed",
            (update["error_message"] as? String) ?? "TDLib send failed.",
            TdlibJson.string(update)
        )
        let waiter = withLock { sendWaiters.removeValue(forKey: key) }
        if let waiter = waiter {
            waiter.fail(error)
        } else {
            cacheFailedSend(key, error)
        }
    }

    private func cacheCompletedSend(_ key: String, _ message: [String: Any]) {
        withLock { completedSends[key] = message }
        expireCachedSend(key)
    }

    private func cacheFailedSend(_ key: String, _ error: TdlibError) {
        withLock { failedSends[key] = error }
        expireCachedSend(key)
    }

    private func expireCachedSend(_ key: String) {
        scheduleTimeout(afterMs: 10 * 60 * 1000) { [weak self] in
            guard let self = self else { return }
            self.withLock {
                _ = self.completedSends.removeValue(forKey: key)
                _ = self.failedSends.removeValue(forKey: key)
            }
        }
    }

    /// 10 minutes base + 1 minute per MiB, capped at 60 minutes.
    func uploadTimeoutMs(_ sizeBytes: Int64?) -> Int {
        let size = sizeBytes ?? 0
        let mib = size / (1024 * 1024)
        let ms: Int64 = 10 * 60 * 1000 + mib * 60 * 1000
        return Int(min(ms, 60 * 60 * 1000))
    }

    // MARK: - Download

    func downloadToFile(_ args: [String: Any]) throws -> Promise<[String: Any]> {
        try ensureAuthorized()
        let transferId = TdlibArgs.string(args, "transferId") ?? UUID().uuidString
        let chatId = TdlibArgs.int64(args, "tdlibChatId")
        let messageId = TdlibArgs.int64(args, "tdlibMessageId")
        let destinationPath = try TdlibArgs.requireString(args, "destinationPath")
        let suppliedFileId: Int? = {
            guard let id = TdlibArgs.int(args, "tdlibFileId"), id > 0 else { return nil }
            return id
        }()
        let remoteFileId: String? = {
            guard let id = TdlibArgs.string(args, "tdlibRemoteFileId"), !TdlibArgs.isBlank(id) else { return nil }
            return id
        }()
        let hasMessageRef = chatId != nil && messageId != nil
        if !hasMessageRef && remoteFileId == nil && suppliedFileId == nil {
            throw TdlibError(
                "tdlib_ref_invalid",
                "TDLib media reference is missing message, remote file, and file id identifiers."
            )
        }
        let timeoutMs = downloadTimeoutMs(
            TdlibArgs.string(args, "variant"),
            {
                guard let requested = TdlibArgs.int64(args, "timeoutMs"), requested > 0 else { return nil }
                return requested
            }()
        )
        withLock { transfers[transferId] = TdlibTransfer(transferId: transferId) }
        let messagePromise: Promise<[String: Any]?> = waitForConnectionReady(timeoutMs: 45000)
            .then { _ -> Promise<[String: Any]?> in
                try self.ensureDownloadActive(transferId)
                if hasMessageRef {
                    return self.send([
                        "@type": "getMessage",
                        "chat_id": NSNumber(value: chatId ?? 0),
                        "message_id": NSNumber(value: messageId ?? 0),
                    ]).handle { message, _ in message }
                }
                return Promise.value(nil)
            }
        emitProgress(transferId, "downloading", 0, nil, nil)
        let result = messagePromise.then { message -> Promise<[String: Any]> in
            try self.ensureDownloadActive(transferId)
            if let message = message,
               let file = TdlibBridge.extractFile(message),
               let fileId = TdlibJson.int(file["id"]), fileId > 0 {
                return self.startDownloadFile(fileId, transferId, destinationPath, timeoutMs)
            }
            return self.downloadByRemoteOrSupplied(remoteFileId, suppliedFileId, transferId, destinationPath, timeoutMs)
        }
        result.onComplete { _ in
            self.withLock { _ = self.transfers.removeValue(forKey: transferId) }
        }
        return result
    }

    private func ensureDownloadActive(_ transferId: String) throws {
        let active = withLock {
            guard let transfer = transfers[transferId] else { return false }
            return !transfer.cancelled
        }
        if !active { throw TdlibError("tdlib_cancelled", "Transfer was cancelled.") }
    }

    private func downloadByRemoteOrSupplied(
        _ remoteFileId: String?,
        _ suppliedFileId: Int?,
        _ transferId: String,
        _ destinationPath: String,
        _ timeoutMs: Int
    ) -> Promise<[String: Any]> {
        if let remoteFileId = remoteFileId {
            return remoteFile(remoteFileId)
                .handle { file, error -> Promise<[String: Any]> in
                    let remoteResolvedFileId: Int? = {
                        guard error == nil, let id = TdlibJson.int(file?["id"]), id > 0 else { return nil }
                        return id
                    }()
                    if let fileId = remoteResolvedFileId {
                        return self.startDownloadFile(fileId, transferId, destinationPath, timeoutMs)
                    }
                    if let fileId = suppliedFileId {
                        return self.startDownloadFile(fileId, transferId, destinationPath, timeoutMs)
                    }
                    if let error = error {
                        return Promise.error(error)
                    }
                    return Promise.error(
                        TdlibError("tdlib_file_ref_missing", "Could not locate TDLib file id for this reference.")
                    )
                }
                .then { $0 }
        }
        if let fileId = suppliedFileId {
            return startDownloadFile(fileId, transferId, destinationPath, timeoutMs)
        }
        return Promise.error(
            TdlibError("tdlib_file_ref_missing", "Could not locate TDLib file id for this reference.")
        )
    }

    private func remoteFile(_ remoteFileId: String) -> Promise<[String: Any]> {
        return send([
            "@type": "getRemoteFile",
            "remote_file_id": remoteFileId,
            "file_type": ["@type": "fileTypeUnknown"] as [String: Any],
        ])
    }

    private func startDownloadFile(
        _ fileId: Int,
        _ transferId: String,
        _ destinationPath: String,
        _ timeoutMs: Int
    ) -> Promise<[String: Any]> {
        let waiter = TdlibDownloadWaiter(transferId: transferId, destinationPath: destinationPath)
        let active = withLock {
            guard let transfer = transfers[transferId], !transfer.cancelled else { return false }
            transfer.fileId = fileId
            downloads[fileId, default: []].append(waiter)
            return true
        }
        guard active else {
            return Promise.error(TdlibError("tdlib_cancelled", "Transfer was cancelled."))
        }
        let request = sendTransferIfActive(transferId, [
            "@type": "downloadFile",
            "file_id": fileId,
            "priority": 32,
            "offset": 0,
            "limit": 0,
            "synchronous": false,
        ])
        request.onComplete { result in
            switch result {
            case .failure(let error):
                self.removeDownloadWaiter(fileId, waiter)
                self.withLock { _ = self.transfers.removeValue(forKey: transferId) }
                let message = (error as? TdlibError)?.message ?? error.localizedDescription
                self.emitProgress(transferId, "failed", 0, nil, message)
                waiter.promise.fail(error)
            case .success(let file):
                // The file may already be complete locally — deliver it now.
                self.handleDownloadedFile(file)
                let local = file["local"] as? [String: Any]
                if TdlibJson.bool(local?["is_downloading_completed"]) != true {
                    let remote = file["remote"] as? [String: Any]
                    if TdlibJson.bool(remote?["is_uploading_completed"]) == false {
                        self.removeDownloadWaiter(fileId, waiter)
                        self.withLock { _ = self.transfers.removeValue(forKey: transferId) }
                        waiter.promise.fail(
                            TdlibError("tdlib_file_unavailable", "Telegram file is not ready to download.")
                        )
                    }
                }
            }
        }
        expireDownloadWaiter(fileId, waiter, timeoutMs: timeoutMs)
        return waiter.promise
    }

    /// Explicit timeoutMs wins (floor 1s); otherwise originals get 10 minutes
    /// and derivative variants 45 seconds.
    func downloadTimeoutMs(_ variant: String?, _ requestedTimeoutMs: Int64?) -> Int {
        if let requested = requestedTimeoutMs {
            return Int(max(requested, 1000))
        }
        return variant == "original" ? 10 * 60 * 1000 : 45 * 1000
    }

    func handleUpdatedFile(_ file: [String: Any]) {
        let fileId = TdlibJson.int(file["id"]) ?? 0
        let size: Int64? = {
            guard let bytes = TdlibJson.int64(file["size"]), bytes > 0 else { return nil }
            return bytes
        }()
        let local = file["local"] as? [String: Any]
        let remote = file["remote"] as? [String: Any]
        let downloaded = TdlibJson.bool(local?["is_downloading_completed"]) == true
        let downloadedBytes = TdlibJson.int64(local?["downloaded_size"]) ?? 0
        let uploadedBytes = TdlibJson.int64(remote?["uploaded_size"]) ?? 0
        let matches: [(transferId: String, isDownload: Bool)] = withLock {
            let isDownload = downloads[fileId] != nil
            return transfers.values
                .filter { $0.fileId == fileId && !$0.cancelled }
                .map { ($0.transferId, isDownload) }
        }
        for match in matches {
            if match.isDownload {
                emitProgress(match.transferId, "downloading", downloadedBytes, size, nil)
            } else {
                emitProgress(match.transferId, "uploading", uploadedBytes, size, nil)
            }
        }
        if downloaded {
            handleDownloadedFile(file)
        }
    }

    func handleDownloadedFile(_ file: [String: Any]) {
        let fileId = TdlibJson.int(file["id"]) ?? 0
        guard let sourcePath = (file["local"] as? [String: Any])?["path"] as? String,
              !TdlibArgs.isBlank(sourcePath) else {
            return
        }
        let waiters: [TdlibDownloadWaiter]? = withLock {
            guard let registered = downloads[fileId] else { return nil }
            downloads.removeValue(forKey: fileId)
            return registered
        }
        guard let waiters = waiters else { return }
        let fileManager = FileManager.default
        for waiter in waiters {
            do {
                let destinationPath = waiter.destinationPath
                let parent = (destinationPath as NSString).deletingLastPathComponent
                try? fileManager.createDirectory(atPath: parent, withIntermediateDirectories: true)
                if sourcePath != destinationPath {
                    // FileManager.copyItem refuses to overwrite, unlike
                    // Kotlin's copyTo(overwrite = true).
                    if fileManager.fileExists(atPath: destinationPath) {
                        try fileManager.removeItem(atPath: destinationPath)
                    }
                    try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                }
                withLock { _ = transfers.removeValue(forKey: waiter.transferId) }
                let sourceLength = ((try? fileManager.attributesOfItem(atPath: sourcePath))?[.size] as? NSNumber)?.int64Value ?? 0
                emitProgress(waiter.transferId, "completed", sourceLength, sourceLength, nil)
                waiter.promise.complete([
                    "filePath": destinationPath,
                    "tdlibFileId": fileId,
                ])
            } catch {
                withLock { _ = transfers.removeValue(forKey: waiter.transferId) }
                let message = error.localizedDescription
                emitProgress(waiter.transferId, "failed", 0, nil, message)
                waiter.promise.fail(TdlibError("tdlib_download_copy_failed", message))
            }
        }
    }

    private func expireDownloadWaiter(_ fileId: Int, _ waiter: TdlibDownloadWaiter, timeoutMs: Int) {
        scheduleTimeout(afterMs: timeoutMs) { [weak self] in
            guard let self = self else { return }
            if self.removeDownloadWaiter(fileId, waiter) {
                self.withLock { _ = self.transfers.removeValue(forKey: waiter.transferId) }
                self.emitProgress(waiter.transferId, "failed", 0, nil, "Timed out waiting for Telegram to download the file.")
                waiter.promise.fail(TdlibError(
                    "tdlib_download_timeout",
                    "Timed out waiting for Telegram to download the file.",
                    "fileId=\(fileId) timeoutMs=\(timeoutMs)"
                ))
            }
        }
    }

    @discardableResult
    private func removeDownloadWaiter(_ fileId: Int, _ waiter: TdlibDownloadWaiter) -> Bool {
        return withLock {
            guard var waiters = downloads[fileId],
                  let index = waiters.firstIndex(where: { $0 === waiter }) else {
                return false
            }
            waiters.remove(at: index)
            if waiters.isEmpty {
                downloads.removeValue(forKey: fileId)
            } else {
                downloads[fileId] = waiters
            }
            return true
        }
    }

    private func removeDownloadWaiter(_ fileId: Int, transferId: String) -> TdlibDownloadWaiter? {
        return withLock {
            guard var waiters = downloads[fileId],
                  let index = waiters.firstIndex(where: { $0.transferId == transferId }) else {
                return nil
            }
            let waiter = waiters.remove(at: index)
            if waiters.isEmpty {
                downloads.removeValue(forKey: fileId)
            } else {
                downloads[fileId] = waiters
            }
            return waiter
        }
    }

    // MARK: - Cancel

    func cancelTransfer(_ args: [String: Any]) throws -> [String: Any] {
        let transferId = try TdlibArgs.requireString(args, "transferId")
        let currentClientId = currentClientIdForCancel
        let cancelled: (TdlibTransfer?, Int?) = withLock {
            let transfer = transfers[transferId]
            if transfer?.uploadChatId == nil { transfers.removeValue(forKey: transferId) }
            transfer?.cancelled = true
            return (transfer, transfer?.fileId)
        }
        cancelled.0?.cancellation.fail(TdlibError("tdlib_cancelled", "Transfer was cancelled."))
        let transferFileId = cancelled.1
        var removedWaiter: TdlibDownloadWaiter?
        if let fileId = transferFileId {
            removedWaiter = removeDownloadWaiter(fileId, transferId: transferId)
            let hasOtherWaiters = withLock { downloads[fileId] != nil }
            if currentClientId != 0 && !hasOtherWaiters {
                sendNoWait(["@type": "cancelDownloadFile", "file_id": fileId, "only_if_pending": false])
            }
        }
        removedWaiter?.promise.fail(TdlibError("tdlib_cancelled", "Transfer was cancelled."))
        let cancelPendingUpload = withLock { cancelled.0?.cancelPendingUpload }
        cancelPendingUpload?()
        emitProgress(transferId, "cancelled", 0, nil, nil)
        return ["cancelled": true]
    }

    // MARK: - Progress events

    /// Throttle identical to the Kotlin bridge: terminal states always emit
    /// (and clear throttle bookkeeping); otherwise emit on state change, first
    /// event, ≥250ms elapsed, or a ≥1% jump. Uses a monotonic clock.
    func emitProgress(_ transferId: String, _ state: String, _ bytesDone: Int64, _ totalBytes: Int64?, _ message: String?) {
        let shouldEmit: Bool = withLock {
            if terminalStates.contains(state) {
                lastEmittedAtByTransferId.removeValue(forKey: transferId)
                lastEmittedFractionByTransferId.removeValue(forKey: transferId)
                lastEmittedStateByTransferId.removeValue(forKey: transferId)
                return true
            }
            let stateChanged = lastEmittedStateByTransferId[transferId] != state
            let now = Int64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
            let last = lastEmittedAtByTransferId[transferId] ?? 0
            let fraction: Int = {
                guard let total = totalBytes, total > 0 else { return -1 }
                let raw = Int((bytesDone * 1000) / total)
                return min(max(raw, 0), 1000)
            }()
            let lastFraction = lastEmittedFractionByTransferId[transferId] ?? -1
            let withinInterval = now - last < progressMinIntervalMs
            let bigJump = fraction >= 0 && lastFraction >= 0 && abs(fraction - lastFraction) >= 10
            if !stateChanged && last != 0 && withinInterval && !bigJump {
                return false
            }
            lastEmittedAtByTransferId[transferId] = now
            if fraction >= 0 {
                lastEmittedFractionByTransferId[transferId] = fraction
            }
            lastEmittedStateByTransferId[transferId] = state
            return true
        }
        guard shouldEmit else { return }
        emitEvent([
            "type": "progress",
            "transferId": transferId,
            "state": state,
            "bytesDone": NSNumber(value: bytesDone),
            "totalBytes": totalBytes.map { NSNumber(value: $0) } ?? NSNull(),
            "message": message ?? NSNull(),
        ])
    }
}
