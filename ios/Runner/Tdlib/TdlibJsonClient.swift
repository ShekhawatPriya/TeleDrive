import Foundation
import TDLibFramework

/// Thin wrapper over TDLib's C JSON interface (td_json_client.h), mirroring
/// org.drinkless.tdlib.JsonClient on Android. The framework is linked at build
/// time, so unlike Android's System.loadLibrary there is no runtime load step.
enum TdlibJsonClient {
    static func createClientId() -> Int32 {
        return td_create_client_id()
    }

    /// Sends a request to the TDLib client. May be called from any thread.
    static func send(_ clientId: Int32, _ request: String) {
        td_send(clientId, request)
    }

    /// Receives incoming updates and request responses. Must only be called
    /// from the single receiver thread. The returned C buffer is invalidated
    /// by the next td_receive/td_execute call, so it is copied immediately.
    static func receive(_ timeout: Double) -> String? {
        guard let pointer = td_receive(timeout) else { return nil }
        return String(cString: pointer)
    }

    /// Synchronously executes a TDLib request (only requests documented as
    /// "Can be called synchronously"). Used once at startup, before the
    /// receiver thread exists, so it never races td_receive's shared buffer.
    @discardableResult
    static func execute(_ request: String) -> String? {
        guard let pointer = td_execute(request) else { return nil }
        return String(cString: pointer)
    }
}
