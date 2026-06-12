import Flutter
import Foundation
import Photos

/// MethodChannel "teledrive/media" handler — the iOS counterpart of the media
/// half of MainActivity.kt. Two serial background queues mirror the Android
/// derivative/io executors; replies are always delivered on the main thread.
final class MediaChannelHandler {
    private let derivativeQueue = DispatchQueue(label: "teledrive.media.derivative", qos: .utility)
    private let ioQueue = DispatchQueue(label: "teledrive.media.io", qos: .utility)
    private let galleryMediaQuery = GalleryMediaQuery()
    private let mediaDerivatives = MediaDerivativeGenerator()
    // Main-thread only, like Android's pendingDeleteResult.
    private var deleteInFlight = false

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        switch call.method {
        case "createImageDerivative":
            runMediaTask(on: derivativeQueue, result) { try self.mediaDerivatives.createImageDerivative(args) }
        case "createVideoThumbnail":
            runMediaTask(on: derivativeQueue, result) { try self.mediaDerivatives.createVideoThumbnail(args) }
        case "listGalleryMedia":
            runMediaTask(on: ioQueue, result) { self.galleryMediaQuery.listGalleryMedia(args) }
        case "copyContentUriToFile":
            runMediaTask(on: ioQueue, result) { try self.galleryMediaQuery.copyContentUriToFile(args) }
        case "deleteGalleryMedia":
            deleteGalleryMedia(args, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func runMediaTask(
        on queue: DispatchQueue,
        _ result: @escaping FlutterResult,
        _ block: @escaping () throws -> Any?
    ) {
        queue.async {
            do {
                let value = try block()
                DispatchQueue.main.async { result(value) }
            } catch {
                let message = (error as? MediaBridgeError)?.message ?? error.localizedDescription
                DispatchQueue.main.async {
                    result(FlutterError(code: "media_derivative_failed", message: message, details: nil))
                }
            }
        }
    }

    // MARK: - Deletion

    /// PHAssetChangeRequest.deleteAssets shows the system confirmation dialog
    /// (the PhotoKit analogue of MediaStore.createDeleteRequest). The result
    /// map mirrors Android exactly, including echoing the caller's URI
    /// strings in deletedUris/failedUris and the userCancelled success path.
    private func deleteGalleryMedia(_ args: [String: Any], _ result: @escaping FlutterResult) {
        if deleteInFlight {
            result(FlutterError(
                code: "media_delete_pending",
                message: "A media deletion request is already open.",
                details: nil
            ))
            return
        }
        let rawUris = (args["contentUris"] as? [Any]) ?? []
        var uris: [String] = []
        var identifiers: [String] = []
        var seenIdentifiers = Set<String>()
        for raw in rawUris {
            guard let text = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  let ref = PhAssetUri.parse(text) else {
                continue
            }
            if seenIdentifiers.insert(ref.localIdentifier).inserted {
                uris.append(text)
                identifiers.append(ref.localIdentifier)
            }
        }
        if identifiers.isEmpty {
            result(deleteResultMap(requested: [], deleted: [], failed: [], userCancelled: false))
            return
        }
        deleteInFlight = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                self.deleteInFlight = false
                if success {
                    // Like Android's post-delete uriExists check: deleted =
                    // the asset no longer resolves, failed = it still does.
                    let remaining = self.existingIdentifiers(identifiers)
                    var deletedUris: [String] = []
                    var failedUris: [String] = []
                    for (uri, identifier) in zip(uris, identifiers) {
                        if remaining.contains(identifier) {
                            failedUris.append(uri)
                        } else {
                            deletedUris.append(uri)
                        }
                    }
                    result(self.deleteResultMap(
                        requested: uris,
                        deleted: deletedUris,
                        failed: failedUris,
                        userCancelled: false
                    ))
                } else if let error = error, self.isUserCancelled(error) {
                    result(self.deleteResultMap(requested: uris, deleted: [], failed: uris, userCancelled: true))
                } else {
                    result(FlutterError(
                        code: "media_delete_failed",
                        message: error?.localizedDescription ?? "Could not request media deletion.",
                        details: nil
                    ))
                }
            }
        }
    }

    private func existingIdentifiers(_ identifiers: [String]) -> Set<String> {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var existing = Set<String>()
        fetchResult.enumerateObjects { asset, _, _ in
            existing.insert(asset.localIdentifier)
        }
        return existing
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == PHPhotosErrorDomain && nsError.code == PHPhotosError.Code.userCancelled.rawValue
    }

    private func deleteResultMap(
        requested: [String],
        deleted: [String],
        failed: [String],
        userCancelled: Bool
    ) -> [String: Any] {
        return [
            "requested": requested.count,
            "deleted": deleted.count,
            "failed": failed.count,
            "userCancelled": userCancelled,
            "deletedUris": deleted,
            "failedUris": failed,
        ]
    }
}
