import Foundation
import Photos
import UniformTypeIdentifiers

/// PhotoKit port of GalleryMediaQuery.kt. Row shapes must match the Android
/// MediaStore implementation field-for-field — the Dart scanner, backup
/// fingerprints, and the backend's /client-backup-assets/resolve endpoint all
/// consume them. `sourceKind` stays "mediastore" verbatim because the Dart
/// free-up-space gate and the backend key on that exact string.
final class GalleryMediaQuery {
    func listGalleryMedia(_ args: [String: Any]) -> [[String: Any]] {
        let limit = min(max((args["limit"] as? NSNumber)?.intValue ?? 100, 1), 500)
        let includeImages = (args["includeImages"] as? NSNumber)?.boolValue ?? true
        let includeVideos = (args["includeVideos"] as? NSNumber)?.boolValue ?? true
        // `strategy` is an Android scoped-storage concept (MediaStore vs raw
        // file paths). PhotoKit is the only gallery source on iOS, so every
        // strategy resolves to the photo library — never return empty for
        // "file_path_only".
        var items: [[String: Any]] = []
        if includeImages {
            items.append(contentsOf: queryAssets(.image, limit: limit))
        }
        if includeVideos {
            items.append(contentsOf: queryAssets(.video, limit: limit))
        }
        items.sort { recencyMillis($0) > recencyMillis($1) }
        return Array(items.prefix(limit))
    }

    private func recencyMillis(_ row: [String: Any]) -> Int64 {
        let modified = (row["modifiedAtMillis"] as? NSNumber)?.int64Value ?? 0
        let added = (row["addedAtMillis"] as? NSNumber)?.int64Value ?? 0
        return max(modified, added)
    }

    private func queryAssets(_ mediaType: PHAssetMediaType, limit: Int) -> [[String: Any]] {
        // Android orders by max(DATE_MODIFIED, DATE_ADDED) in SQL before its
        // LIMIT. PHFetchOptions can only sort by one key at a time, so fetch
        // the top `limit` by each key and union: any asset in the true top-N
        // by max(created, modified) is in the top-N of at least one key.
        var assetsById: [String: PHAsset] = [:]
        for sortKey in ["modificationDate", "creationDate"] {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]
            options.fetchLimit = limit
            let fetchResult = PHAsset.fetchAssets(with: mediaType, options: options)
            fetchResult.enumerateObjects { asset, _, _ in
                assetsById[asset.localIdentifier] = asset
            }
        }
        var rows: [[String: Any]] = []
        for asset in assetsById.values {
            if let row = assetRow(asset, mediaType) {
                rows.append(row)
            }
        }
        return rows
    }

    private func assetRow(_ asset: PHAsset, _ mediaType: PHAssetMediaType) -> [String: Any]? {
        let typeName = mediaType == .video ? "video" : "image"
        let resource = primaryResource(for: asset, mediaType: mediaType)
        let sizeBytes = resource.flatMap { resourceFileSize($0) } ?? 0
        // Mirrors the Android bridge's size<=0 skip — rows without a concrete
        // byte size cannot be fingerprinted or uploaded.
        guard sizeBytes > 0 else { return nil }
        let name = resource?.originalFilename ?? "\(typeName)-\(asset.localIdentifier)"
        let mimeType = resource
            .flatMap { UTType($0.uniformTypeIdentifier)?.preferredMIMEType }
            ?? (typeName == "video" ? "video/mp4" : "image/jpeg")
        let created = asset.creationDate ?? asset.modificationDate
        let modified = asset.modificationDate ?? created
        let modifiedAtMillis = Int64((modified?.timeIntervalSince1970 ?? 0) * 1000)
        let addedAtMillis = Int64((created?.timeIntervalSince1970 ?? 0) * 1000)
        return [
            "id": "\(typeName):\(asset.localIdentifier)",
            "contentUri": PhAssetUri.make(mediaType: typeName, localIdentifier: asset.localIdentifier),
            "sourceKind": "mediastore",
            // PhotoKit exposes no stable filesystem path; the Dart side
            // already falls back to copyContentUriToFile when path is null.
            "path": NSNull(),
            "name": name,
            "sizeBytes": NSNumber(value: sizeBytes),
            "mimeType": mimeType,
            "mediaType": typeName,
            "relativePath": NSNull(),
            "modifiedAtMillis": NSNumber(value: modifiedAtMillis),
            "addedAtMillis": NSNumber(value: addedAtMillis),
            "durationMs": mediaType == .video
                ? NSNumber(value: Int64(asset.duration * 1000)) as Any
                : NSNull() as Any,
        ]
    }

    func primaryResource(for asset: PHAsset, mediaType: PHAssetMediaType) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        let wanted: PHAssetResourceType = mediaType == .video ? .video : .photo
        return resources.first(where: { $0.type == wanted }) ?? resources.first
    }

    /// PHAssetResource has no public byte-size API; the "fileSize" key has
    /// been stable since iOS 8 and a 0/absent value simply skips the row.
    /// If the key ever disappears, every row would be skipped and the scan
    /// would go silently empty — log that condition once so it's diagnosable.
    private static var loggedMissingFileSize = false

    private func resourceFileSize(_ resource: PHAssetResource) -> Int64? {
        guard let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value else {
            if !Self.loggedMissingFileSize {
                Self.loggedMissingFileSize = true
                NSLog("TeleDrive: PHAssetResource fileSize unavailable; gallery rows will be skipped")
            }
            return nil
        }
        return size
    }

    /// Android's copyContentUriToFile analogue: streams the original bytes of
    /// a phasset:// item into destinationPath. Blocks the calling (serial
    /// background) queue until PhotoKit finishes writing.
    func copyContentUriToFile(_ args: [String: Any]) throws -> [String: Any] {
        guard let contentUri = args["contentUri"] as? String else {
            throw MediaBridgeError(message: "contentUri is required")
        }
        guard let destinationPath = args["destinationPath"] as? String else {
            throw MediaBridgeError(message: "destinationPath is required")
        }
        guard let ref = PhAssetUri.parse(contentUri) else {
            throw MediaBridgeError(message: "Unsupported media URI")
        }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [ref.localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject,
              let resource = primaryResource(for: asset, mediaType: asset.mediaType) else {
            throw MediaBridgeError(message: "Could not open media item")
        }
        let destinationURL = URL(fileURLWithPath: destinationPath)
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.removeItem(at: destinationURL)
        let options = PHAssetResourceRequestOptions()
        // Originals may be offloaded to iCloud ("Optimize iPhone Storage").
        options.isNetworkAccessAllowed = true
        let semaphore = DispatchSemaphore(value: 0)
        var writeError: Error?
        PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: options) { error in
            writeError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let error = writeError {
            throw MediaBridgeError(message: error.localizedDescription)
        }
        let sizeBytes = ((try? fileManager.attributesOfItem(atPath: destinationURL.path))?[.size] as? NSNumber)?.int64Value ?? 0
        return [
            "path": destinationURL.path,
            "sizeBytes": NSNumber(value: sizeBytes),
        ]
    }
}
