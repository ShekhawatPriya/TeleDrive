import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// ImageIO/AVFoundation port of MediaDerivativeGenerator.kt: downscaled JPEG
/// thumbnails for images (HEIC decodes natively) and a poster frame for
/// videos. Argument defaults and result map shapes match the Kotlin side.
final class MediaDerivativeGenerator {
    func createImageDerivative(_ args: [String: Any]) throws -> [String: Any] {
        guard let sourcePath = args["sourcePath"] as? String else {
            throw MediaBridgeError(message: "sourcePath is required")
        }
        guard let destinationPath = args["destinationPath"] as? String else {
            throw MediaBridgeError(message: "destinationPath is required")
        }
        let maxEdge = max((args["maxEdge"] as? NSNumber)?.intValue ?? 360, 1)
        let quality = min(max((args["quality"] as? NSNumber)?.intValue ?? 82, 1), 100)
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            throw MediaBridgeError(message: "Image file does not exist")
        }
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw MediaBridgeError(message: "Failed to decode image")
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bakes EXIF orientation into the pixels, like ImageDecoder on
            // Android.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else {
            throw MediaBridgeError(message: "Failed to decode image")
        }
        return try writeJpeg(image, destinationPath: destinationPath, quality: quality)
    }

    func createVideoThumbnail(_ args: [String: Any]) throws -> [String: Any] {
        guard let sourcePath = args["sourcePath"] as? String else {
            throw MediaBridgeError(message: "sourcePath is required")
        }
        guard let destinationPath = args["destinationPath"] as? String else {
            throw MediaBridgeError(message: "destinationPath is required")
        }
        let maxEdge = max((args["maxEdge"] as? NSNumber)?.intValue ?? 360, 1)
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            throw MediaBridgeError(message: "Video file does not exist")
        }
        let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)
        let image: CGImage
        do {
            image = try generator.copyCGImage(at: CMTime(value: 0, timescale: 600), actualTime: nil)
        } catch {
            throw MediaBridgeError(message: "Could not create video thumbnail")
        }
        // The Android bridge hardcodes JPEG quality 82 for video posters.
        return try writeJpeg(image, destinationPath: destinationPath, quality: 82)
    }

    private func writeJpeg(_ image: CGImage, destinationPath: String, quality: Int) throws -> [String: Any] {
        let destinationURL = URL(fileURLWithPath: destinationPath)
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.removeItem(at: destinationURL)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaBridgeError(message: "Could not write derivative")
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaBridgeError(message: "Could not write derivative")
        }
        let sizeBytes = ((try? fileManager.attributesOfItem(atPath: destinationURL.path))?[.size] as? NSNumber)?.int64Value ?? 0
        return [
            "path": destinationURL.path,
            "width": image.width,
            "height": image.height,
            "sizeBytes": NSNumber(value: sizeBytes),
        ]
    }
}
