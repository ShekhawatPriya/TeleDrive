import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ClientDerivativeSet {
  const ClientDerivativeSet({this.thumbnail, this.preview});

  final ClientDerivativeAsset? thumbnail;
  final ClientDerivativeAsset? preview;

  Iterable<ClientDerivativeAsset> get assets sync* {
    if (thumbnail != null) yield thumbnail!;
    if (preview != null) yield preview!;
  }
}

class ClientDerivativeAsset {
  const ClientDerivativeAsset({
    required this.variant,
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.widthPx,
    this.heightPx,
    this.durationMs,
  });

  final String variant;
  final String path;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final int? widthPx;
  final int? heightPx;
  final int? durationMs;
}

class ClientDerivativeGenerator {
  const ClientDerivativeGenerator({MethodChannel? mediaChannel})
    : _mediaChannel = mediaChannel ?? const MethodChannel('teledrive/media');

  static const thumbnailMaxEdge = 360;
  static const previewMaxEdge = 1600;
  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
    '.avif',
    '.gif',
    '.bmp',
    '.tif',
    '.tiff',
  };

  final MethodChannel _mediaChannel;

  Future<ClientDerivativeSet> generate({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required String mimeType,
    required bool requiresThumbnail,
    required bool requiresPreview,
    bool allowVideoPreview = false,
  }) async {
    if (_isImageInput(originalFilename, originalPath, mimeType)) {
      return _generateImageSet(
        localId: localId,
        originalPath: originalPath,
        originalFilename: originalFilename,
        mimeType: mimeType,
        requiresThumbnail: requiresThumbnail,
        requiresPreview: requiresPreview,
      );
    }
    if (mimeType.startsWith('video/')) {
      return _generateVideoSet(
        localId: localId,
        originalPath: originalPath,
        originalFilename: originalFilename,
        requiresThumbnail: requiresThumbnail,
        requiresPreview: requiresPreview && allowVideoPreview,
      );
    }
    return const ClientDerivativeSet();
  }

  bool _isImageInput(
    String originalFilename,
    String originalPath,
    String mimeType,
  ) {
    final normalizedMimeType = mimeType.toLowerCase();
    final filenameExtension = p.extension(originalFilename).toLowerCase();
    final pathExtension = p.extension(originalPath).toLowerCase();
    return normalizedMimeType.startsWith('image/') ||
        _imageExtensions.contains(filenameExtension) ||
        _imageExtensions.contains(pathExtension);
  }

  Future<ClientDerivativeSet> _generateImageSet({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required String mimeType,
    required bool requiresThumbnail,
    required bool requiresPreview,
  }) async {
    if (!requiresThumbnail && !requiresPreview)
      return const ClientDerivativeSet();
    if (_isHeicImage(originalFilename, originalPath, mimeType)) {
      return _generateNativeImageSet(
        localId: localId,
        originalPath: originalPath,
        originalFilename: originalFilename,
        requiresThumbnail: requiresThumbnail,
        requiresPreview: requiresPreview,
      );
    }
    if (Platform.isAndroid) {
      final native = await _tryNativeImageSet(
        localId: localId,
        originalPath: originalPath,
        originalFilename: originalFilename,
        requiresThumbnail: requiresThumbnail,
        requiresPreview: requiresPreview,
      );
      if (native != null) return native;
    }
    final bytes = await File(originalPath).readAsBytes();
    final decoded = _tryDecodeImage(bytes);
    if (decoded == null) return const ClientDerivativeSet();
    final oriented = img.bakeOrientation(decoded);
    final thumbnail = requiresThumbnail
        ? await _writeImageVariant(
            source: oriented,
            localId: localId,
            originalFilename: originalFilename,
            variant: 'thumbnail',
            maxEdge: thumbnailMaxEdge,
            quality: 76,
          )
        : null;
    final preview = requiresPreview
        ? await _writeImageVariant(
            source: oriented,
            localId: localId,
            originalFilename: originalFilename,
            variant: 'preview',
            maxEdge: previewMaxEdge,
            quality: 86,
          )
        : null;
    return ClientDerivativeSet(thumbnail: thumbnail, preview: preview);
  }

  Future<ClientDerivativeSet?> _tryNativeImageSet({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required bool requiresThumbnail,
    required bool requiresPreview,
  }) async {
    ClientDerivativeAsset? thumbnail;
    if (requiresThumbnail) {
      thumbnail = await _createNativeImageDerivative(
        localId: localId,
        originalPath: originalPath,
        originalFilename: originalFilename,
        variant: 'thumbnail',
        maxEdge: thumbnailMaxEdge,
        quality: 76,
      );
      if (thumbnail == null) return null;
    }
    ClientDerivativeAsset? preview;
    if (requiresPreview) {
      preview = await _createNativeImageDerivative(
        localId: localId,
        originalPath: originalPath,
        originalFilename: originalFilename,
        variant: 'preview',
        maxEdge: previewMaxEdge,
        quality: 86,
      );
      if (preview == null) return null;
    }
    return ClientDerivativeSet(thumbnail: thumbnail, preview: preview);
  }

  Future<ClientDerivativeSet> _generateNativeImageSet({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required bool requiresThumbnail,
    required bool requiresPreview,
  }) async {
    final thumbnail = requiresThumbnail
        ? await _createNativeImageDerivative(
            localId: localId,
            originalPath: originalPath,
            originalFilename: originalFilename,
            variant: 'thumbnail',
            maxEdge: thumbnailMaxEdge,
            quality: 76,
          )
        : null;
    final preview = requiresPreview
        ? await _createNativeImageDerivative(
            localId: localId,
            originalPath: originalPath,
            originalFilename: originalFilename,
            variant: 'preview',
            maxEdge: previewMaxEdge,
            quality: 86,
          )
        : null;
    return ClientDerivativeSet(thumbnail: thumbnail, preview: preview);
  }

  Future<ClientDerivativeAsset?> _writeImageVariant({
    required img.Image source,
    required String localId,
    required String originalFilename,
    required String variant,
    required int maxEdge,
    required int quality,
  }) async {
    final resized = _resizeToMaxEdge(source, maxEdge);
    final encoded = img.encodeJpg(resized, quality: quality);
    final out = await _derivativeFile(
      localId,
      originalFilename,
      variant,
      'jpg',
    );
    await out.writeAsBytes(encoded, flush: true);
    final stat = await out.stat();
    return ClientDerivativeAsset(
      variant: variant,
      path: out.path,
      filename: p.basename(out.path),
      mimeType: 'image/jpeg',
      sizeBytes: stat.size,
      widthPx: resized.width,
      heightPx: resized.height,
    );
  }

  img.Image? _tryDecodeImage(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  Future<ClientDerivativeAsset?> _createNativeImageDerivative({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required String variant,
    required int maxEdge,
    required int quality,
  }) async {
    try {
      final out = await _derivativeFile(
        localId,
        originalFilename,
        variant,
        'jpg',
      );
      final result = await _mediaChannel
          .invokeMapMethod<String, Object?>('createImageDerivative', {
            'sourcePath': originalPath,
            'destinationPath': out.path,
            'maxEdge': maxEdge,
            'quality': quality,
          });
      final outputPath = (result?['path'] as String?) ?? out.path;
      final file = File(outputPath);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      return ClientDerivativeAsset(
        variant: variant,
        path: outputPath,
        filename: p.basename(outputPath),
        mimeType: 'image/jpeg',
        sizeBytes: stat.size,
        widthPx: (result?['width'] as num?)?.toInt(),
        heightPx: (result?['height'] as num?)?.toInt(),
      );
    } on MissingPluginException catch (err) {
      debugPrint('Native image derivative missing plugin: $err');
      return null;
    } on PlatformException catch (err) {
      debugPrint('Native image derivative failed: ${err.code} ${err.message}');
      return null;
    }
  }

  Future<ClientDerivativeSet> _generateVideoSet({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required bool requiresThumbnail,
    required bool requiresPreview,
  }) async {
    if (!requiresThumbnail && !requiresPreview)
      return const ClientDerivativeSet();
    final thumbnail = requiresThumbnail
        ? await _createNativeVideoThumbnail(
            localId: localId,
            originalPath: originalPath,
            originalFilename: originalFilename,
            variant: 'thumbnail',
            maxEdge: thumbnailMaxEdge,
          )
        : null;
    final preview = requiresPreview
        ? await _createNativeVideoThumbnail(
            localId: localId,
            originalPath: originalPath,
            originalFilename: originalFilename,
            variant: 'preview',
            maxEdge: previewMaxEdge,
          )
        : null;
    return ClientDerivativeSet(thumbnail: thumbnail, preview: preview);
  }

  Future<ClientDerivativeAsset?> _createNativeVideoThumbnail({
    required String localId,
    required String originalPath,
    required String originalFilename,
    required String variant,
    required int maxEdge,
  }) async {
    try {
      final out = await _derivativeFile(
        localId,
        originalFilename,
        variant,
        'jpg',
      );
      final result = await _mediaChannel.invokeMapMethod<String, Object?>(
        'createVideoThumbnail',
        {
          'sourcePath': originalPath,
          'destinationPath': out.path,
          'maxEdge': maxEdge,
        },
      );
      final outputPath = (result?['path'] as String?) ?? out.path;
      final file = File(outputPath);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      return ClientDerivativeAsset(
        variant: variant,
        path: outputPath,
        filename: p.basename(outputPath),
        mimeType: 'image/jpeg',
        sizeBytes: stat.size,
        widthPx: (result?['width'] as num?)?.toInt(),
        heightPx: (result?['height'] as num?)?.toInt(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  img.Image _resizeToMaxEdge(img.Image source, int maxEdge) {
    final largest = source.width > source.height ? source.width : source.height;
    if (largest <= maxEdge) return source;
    final ratio = maxEdge / largest;
    final width = (source.width * ratio).round().clamp(1, maxEdge);
    final height = (source.height * ratio).round().clamp(1, maxEdge);
    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }

  bool _isHeicImage(
    String originalFilename,
    String originalPath,
    String mimeType,
  ) {
    final filenameExtension = p.extension(originalFilename).toLowerCase();
    final pathExtension = p.extension(originalPath).toLowerCase();
    final normalizedMimeType = mimeType.toLowerCase();
    return filenameExtension == '.heic' ||
        filenameExtension == '.heif' ||
        pathExtension == '.heic' ||
        pathExtension == '.heif' ||
        normalizedMimeType == 'image/heic' ||
        normalizedMimeType == 'image/heif';
  }

  Future<File> _derivativeFile(
    String localId,
    String originalFilename,
    String variant,
    String extension,
  ) async {
    final dir = await getTemporaryDirectory();
    final root = Directory(p.join(dir.path, 'teledrive', 'client_derivatives'));
    if (!await root.exists()) await root.create(recursive: true);
    final base = p
        .basenameWithoutExtension(originalFilename)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final safeBase = base.isEmpty ? 'media' : base;
    return File(p.join(root.path, '${localId}_$safeBase.$variant.$extension'));
  }
}
