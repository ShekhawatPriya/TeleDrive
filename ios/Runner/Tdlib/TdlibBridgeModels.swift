import Foundation

/// Error surfaced to Dart as FlutterError(code:message:details:), mirroring
/// TdlibException on Android. Codes must stay byte-identical to the Kotlin
/// bridge — the Dart layer matches on them.
struct TdlibError: Error {
    let code: String
    let message: String
    let details: String?

    init(_ code: String, _ message: String, _ details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

/// Complete-once future, the CompletableFuture stand-in the Kotlin bridge is
/// built around. Callbacks run synchronously on whichever thread settles the
/// promise (matching CompletableFuture's same-thread completion semantics).
final class Promise<T> {
    private let lock = NSLock()
    private var outcome: Result<T, Error>?
    private var callbacks: [(Result<T, Error>) -> Void] = []

    var isDone: Bool {
        lock.lock()
        defer { lock.unlock() }
        return outcome != nil
    }

    private var currentOutcome: Result<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return outcome
    }

    @discardableResult
    func complete(_ value: T) -> Bool {
        return settle(.success(value))
    }

    @discardableResult
    func fail(_ error: Error) -> Bool {
        return settle(.failure(error))
    }

    private func settle(_ result: Result<T, Error>) -> Bool {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return false
        }
        outcome = result
        let pendingCallbacks = callbacks
        callbacks = []
        lock.unlock()
        for callback in pendingCallbacks {
            callback(result)
        }
        return true
    }

    func onComplete(_ callback: @escaping (Result<T, Error>) -> Void) {
        lock.lock()
        if let settled = outcome {
            lock.unlock()
            callback(settled)
            return
        }
        callbacks.append(callback)
        lock.unlock()
    }

    /// CompletableFuture.thenApply — a throwing transform fails the result.
    func map<U>(_ transform: @escaping (T) throws -> U) -> Promise<U> {
        let next = Promise<U>()
        onComplete { result in
            switch result {
            case .success(let value):
                do {
                    next.complete(try transform(value))
                } catch {
                    next.fail(error)
                }
            case .failure(let error):
                next.fail(error)
            }
        }
        return next
    }

    /// CompletableFuture.thenCompose.
    func then<U>(_ transform: @escaping (T) throws -> Promise<U>) -> Promise<U> {
        let next = Promise<U>()
        onComplete { result in
            switch result {
            case .success(let value):
                do {
                    try transform(value).onComplete { inner in
                        switch inner {
                        case .success(let innerValue): next.complete(innerValue)
                        case .failure(let innerError): next.fail(innerError)
                        }
                    }
                } catch {
                    next.fail(error)
                }
            case .failure(let error):
                next.fail(error)
            }
        }
        return next
    }

    /// CompletableFuture.handle — observes value-or-error and never fails.
    func handle<U>(_ transform: @escaping (T?, Error?) -> U) -> Promise<U> {
        let next = Promise<U>()
        onComplete { result in
            switch result {
            case .success(let value): next.complete(transform(value, nil))
            case .failure(let error): next.complete(transform(nil, error))
            }
        }
        return next
    }

    /// CompletableFuture.get(timeout) — used only by the blocking close during
    /// reconfigure, which runs on the serial method queue (never the main or
    /// receiver thread).
    func wait(timeoutMs: Int) -> Result<T, Error>? {
        let semaphore = DispatchSemaphore(value: 0)
        onComplete { _ in semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + .milliseconds(timeoutMs))
        return currentOutcome
    }

    static func value(_ value: T) -> Promise<T> {
        let promise = Promise<T>()
        promise.complete(value)
        return promise
    }

    static func error(_ error: Error) -> Promise<T> {
        let promise = Promise<T>()
        promise.fail(error)
        return promise
    }
}

struct TdlibConfig {
    let databaseDirectory: String
    let filesDirectory: String
    let apiId: Int
    let apiHash: String
    let encryptionKey: String
    let expectedTelegramUserId: Int64
    let applicationVersion: String
}

/// Mutable fields are guarded by TdlibBridge's state lock (the Kotlin
/// counterpart used @Volatile).
final class TdlibTransfer {
    let transferId: String
    var fileId: Int?
    var cancelled = false
    let cancellation = Promise<String>()
    var cancelPendingUpload: (() -> Void)?
    let uploadChatId: Int64?
    var deletedMessageIds = Set<Int64>()
    var onUploadDeleted: (() -> Void)?

    init(transferId: String, fileId: Int? = nil, uploadChatId: Int64? = nil) {
        self.transferId = transferId
        self.fileId = fileId
        self.uploadChatId = uploadChatId
    }
}

final class TdlibDownloadWaiter {
    let transferId: String
    let destinationPath: String
    let promise = Promise<[String: Any]>()

    init(transferId: String, destinationPath: String) {
        self.transferId = transferId
        self.destinationPath = destinationPath
    }
}

final class TdlibAuthorizationWaiter {
    let acceptedStates: Set<String>
    let promise: Promise<String>

    init(acceptedStates: Set<String>, promise: Promise<String>) {
        self.acceptedStates = acceptedStates
        self.promise = promise
    }
}

final class TdlibConnectionWaiter {
    let acceptedStates: Set<String>
    let promise: Promise<String>

    init(acceptedStates: Set<String>, promise: Promise<String>) {
        self.acceptedStates = acceptedStates
        self.promise = promise
    }
}
