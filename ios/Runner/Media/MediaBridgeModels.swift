import Foundation

/// Failure surfaced over the media channel; the handler maps it to a
/// FlutterError whose code matches the Android side ("media_derivative_failed"
/// for task methods, "media_delete_failed" for deletions).
struct MediaBridgeError: Error {
    let message: String
}

/// iOS gallery asset URI minted by GalleryMediaQuery:
/// `phasset://image/<localIdentifier>` or `phasset://video/<localIdentifier>`.
/// PHAsset local identifiers contain `/`, so everything after the media-type
/// segment is the identifier.
enum PhAssetUri {
    struct Ref {
        let mediaType: String
        let localIdentifier: String
    }

    static func make(mediaType: String, localIdentifier: String) -> String {
        return "phasset://\(mediaType)/\(localIdentifier)"
    }

    static func parse(_ uri: String) -> Ref? {
        for mediaType in ["image", "video"] {
            let prefix = "phasset://\(mediaType)/"
            if uri.hasPrefix(prefix) {
                let identifier = String(uri.dropFirst(prefix.count))
                if !identifier.isEmpty {
                    return Ref(mediaType: mediaType, localIdentifier: identifier)
                }
            }
        }
        return nil
    }
}
