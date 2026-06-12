import Foundation

/// Method-channel argument coercion, mirroring TdlibBridgeUtils.kt: numeric
/// arguments accept both numbers and numeric strings; required strings must
/// be non-blank.
enum TdlibArgs {
    static func string(_ args: [String: Any], _ key: String) -> String? {
        return args[key] as? String
    }

    static func int(_ args: [String: Any], _ key: String) -> Int? {
        switch args[key] {
        case let number as NSNumber:
            return number.intValue
        case let text as String:
            return Int(text)
        default:
            return nil
        }
    }

    static func int64(_ args: [String: Any], _ key: String) -> Int64? {
        switch args[key] {
        case let number as NSNumber:
            return number.int64Value
        case let text as String:
            return Int64(text)
        default:
            return nil
        }
    }

    static func requireString(_ args: [String: Any], _ key: String) throws -> String {
        guard let value = string(args, key), !isBlank(value) else {
            throw TdlibError("tdlib_argument_missing", "\(key) is required.")
        }
        return value
    }

    static func isBlank(_ value: String) -> Bool {
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// JSON value helpers over the Foundation objects produced and consumed by
/// JSONSerialization.
enum TdlibJson {
    static func string(_ json: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func parse(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return object as? [String: Any]
    }

    static func int(_ value: Any?) -> Int? {
        return (value as? NSNumber)?.intValue
    }

    static func int64(_ value: Any?) -> Int64? {
        return (value as? NSNumber)?.int64Value
    }

    static func bool(_ value: Any?) -> Bool? {
        return (value as? NSNumber)?.boolValue
    }
}

/// Device metadata for setTdlibParameters — the iOS analogue of the
/// Build.MANUFACTURER/Build.MODEL/Build.VERSION fields used on Android.
enum TdlibDeviceInfo {
    /// e.g. "Apple iPhone15,3" (the simulator reports "Apple arm64").
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        var machine = ""
        for child in Mirror(reflecting: systemInfo.machine).children {
            guard let byte = child.value as? Int8, byte != 0 else { break }
            machine.append(Character(UnicodeScalar(UInt8(bitPattern: byte))))
        }
        return "Apple \(machine.isEmpty ? "iPhone" : machine)"
    }

    /// e.g. "iOS 18.4". ProcessInfo is documented thread-safe, unlike UIDevice.
    static var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var text = "iOS \(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion > 0 {
            text += ".\(version.patchVersion)"
        }
        return text
    }

    /// Fallback when Dart does not pass applicationVersion (the Android
    /// bridge falls back to PackageInfo.versionName).
    static var fallbackApplicationVersion: String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
