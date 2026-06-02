import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GalleryMediaAsset {
  const GalleryMediaAsset({
    required this.id,
    required this.contentUri,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.mediaType,
    required this.modifiedAtMillis,
    required this.addedAtMillis,
    required this.sourceKind,
    this.path,
    this.relativePath,
    this.durationMs,
  });

  final String id;
  final String contentUri;
  final String name;
  final int sizeBytes;
  final String mimeType;
  final String mediaType;
  final int modifiedAtMillis;
  final int addedAtMillis;
  final String sourceKind;
  final String? path;
  final String? relativePath;
  final int? durationMs;

  int get recencyMillis {
    if (modifiedAtMillis <= 0) return addedAtMillis;
    if (addedAtMillis <= 0) return modifiedAtMillis;
    return modifiedAtMillis > addedAtMillis ? modifiedAtMillis : addedAtMillis;
  }

  String get stableKey => fingerprint;

  String get fingerprint {
    final normalizedPath = _normalizePath(path);
    if (sourceKind == 'path' && normalizedPath != null) {
      return [
        'path',
        normalizedPath,
        mediaType,
        mimeType,
        sizeBytes,
        modifiedAtMillis,
      ].join('|');
    }
    return [
      'mediastore',
      mediaType,
      id,
      contentUri,
      sizeBytes,
      modifiedAtMillis,
      addedAtMillis,
      relativePath ?? '',
      name,
    ].join('|');
  }

  String get physicalKey {
    final normalizedPath = _normalizePath(path);
    if (normalizedPath != null) {
      return 'path|$normalizedPath|$sizeBytes|$modifiedAtMillis';
    }
    if (relativePath != null && relativePath!.trim().isNotEmpty) {
      return [
        'relative',
        relativePath!.trim().toLowerCase(),
        name.trim().toLowerCase(),
        sizeBytes,
      ].join('|');
    }
    return 'content|$contentUri|$sizeBytes|$modifiedAtMillis';
  }

  GalleryMediaAsset mergeWith(GalleryMediaAsset other) {
    if (sourceKind == 'mediastore') return this;
    if (other.sourceKind == 'mediastore') return other;
    return recencyMillis >= other.recencyMillis ? this : other;
  }

  factory GalleryMediaAsset.fromJson(Map<String, dynamic> json) {
    return GalleryMediaAsset(
      id: '${json['id']}',
      contentUri: '${json['contentUri']}',
      name: '${json['name'] ?? 'media'}',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: '${json['mimeType'] ?? 'application/octet-stream'}',
      mediaType: '${json['mediaType'] ?? 'image'}',
      modifiedAtMillis: (json['modifiedAtMillis'] as num?)?.toInt() ?? 0,
      addedAtMillis: (json['addedAtMillis'] as num?)?.toInt() ?? 0,
      sourceKind: '${json['sourceKind'] ?? 'mediastore'}',
      path: json['path'] as String?,
      relativePath: json['relativePath'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }

  static String? _normalizePath(String? value) {
    final path = value?.trim();
    if (path == null || path.isEmpty) return null;
    return p.normalize(path).toLowerCase();
  }
}

class GalleryMediaScanResult {
  const GalleryMediaScanResult({
    required this.assets,
    required this.mediaStoreCount,
    required this.pathCount,
    required this.mergedCount,
    this.permissionSkipCount = 0,
    this.invalidSkipCount = 0,
    this.diagnostics = const [],
  });

  final List<GalleryMediaAsset> assets;
  final int mediaStoreCount;
  final int pathCount;
  final int mergedCount;
  final int permissionSkipCount;
  final int invalidSkipCount;
  final List<String> diagnostics;
}

class GalleryMediaDeleteResult {
  const GalleryMediaDeleteResult({
    required this.requested,
    required this.deleted,
    required this.failed,
    required this.userCancelled,
    required this.deletedUris,
    required this.failedUris,
  });

  final int requested;
  final int deleted;
  final int failed;
  final bool userCancelled;
  final List<String> deletedUris;
  final List<String> failedUris;

  factory GalleryMediaDeleteResult.fromJson(Map<String, Object?> json) {
    return GalleryMediaDeleteResult(
      requested: (json['requested'] as num?)?.toInt() ?? 0,
      deleted: (json['deleted'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      userCancelled: json['userCancelled'] == true,
      deletedUris: (json['deletedUris'] as List? ?? const [])
          .map((value) => '$value')
          .toList(),
      failedUris: (json['failedUris'] as List? ?? const [])
          .map((value) => '$value')
          .toList(),
    );
  }
}

class GalleryMediaScannerException implements Exception {
  const GalleryMediaScannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GalleryMediaScanner {
  const GalleryMediaScanner({MethodChannel? mediaChannel})
    : _mediaChannel = mediaChannel ?? const MethodChannel('teledrive/media');

  final MethodChannel _mediaChannel;

  Future<GalleryMediaScanResult> scanRecent({
    int limit = 100,
    bool includeImages = true,
    bool includeVideos = true,
    String strategy = 'media_store_only',
  }) async {
    final result = await _mediaChannel
        .invokeListMethod<Object?>('listGalleryMedia', {
          'limit': limit,
          'includeImages': includeImages,
          'includeVideos': includeVideos,
          'strategy': strategy,
        });
    final maps = (result ?? const [])
        .whereType<Map>()
        .map(
          (item) => GalleryMediaAsset.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final valid = maps
        .where((asset) => asset.sizeBytes > 0 && asset.contentUri.isNotEmpty)
        .toList();
    final merged = <String, GalleryMediaAsset>{};
    for (final asset in valid) {
      final existing = merged[asset.physicalKey];
      merged[asset.physicalKey] = existing == null
          ? asset
          : existing.mergeWith(asset);
    }
    final assets = merged.values.toList()
      ..sort((a, b) => b.recencyMillis.compareTo(a.recencyMillis));
    return GalleryMediaScanResult(
      assets: assets.take(limit).toList(),
      mediaStoreCount: valid.where((a) => a.sourceKind == 'mediastore').length,
      pathCount: valid.where((a) => a.sourceKind == 'path').length,
      mergedCount: assets.length,
      invalidSkipCount: maps.length - valid.length,
    );
  }

  Future<GalleryMediaDeleteResult> deleteMediaUris(
    List<String> contentUris,
  ) async {
    final uris = contentUris
        .map((uri) => uri.trim())
        .where(isConcreteMediaStoreContentUri)
        .toList();
    if (uris.isEmpty) {
      return const GalleryMediaDeleteResult(
        requested: 0,
        deleted: 0,
        failed: 0,
        userCancelled: false,
        deletedUris: [],
        failedUris: [],
      );
    }
    try {
      final result = await _mediaChannel.invokeMapMethod<String, Object?>(
        'deleteGalleryMedia',
        {'contentUris': uris},
      );
      return GalleryMediaDeleteResult.fromJson(result ?? const {});
    } on PlatformException catch (err) {
      throw GalleryMediaScannerException(
        err.message ?? 'Android could not remove the selected media.',
      );
    }
  }

  Future<({String path, bool deleteWhenDone})> localPathFor(
    GalleryMediaAsset asset,
  ) async {
    final directPath = asset.path;
    if (directPath != null && directPath.isNotEmpty) {
      final file = File(directPath);
      if (await file.exists()) return (path: directPath, deleteWhenDone: false);
    }
    final destination = await _cacheFileFor(asset);
    final result = await _mediaChannel.invokeMapMethod<String, Object?>(
      'copyContentUriToFile',
      {'contentUri': asset.contentUri, 'destinationPath': destination.path},
    );
    return (
      path: (result?['path'] as String?) ?? destination.path,
      deleteWhenDone: true,
    );
  }

  Future<File> _cacheFileFor(GalleryMediaAsset asset) async {
    final dir = await getTemporaryDirectory();
    final root = Directory(p.join(dir.path, 'teledrive', 'gallery_backup'));
    if (!await root.exists()) await root.create(recursive: true);
    final safeName = asset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fallbackName = asset.mediaType == 'video' ? 'video.mp4' : 'image.jpg';
    final name = safeName.trim().isEmpty ? fallbackName : safeName;
    return File(p.join(root.path, '${asset.stableKey.hashCode}_$name'));
  }

  static bool isConcreteMediaStoreContentUri(String value) {
    if (!value.startsWith('content://media/')) return false;
    if (!value.contains('/images/media/') && !value.contains('/video/media/')) {
      return false;
    }
    return int.tryParse(value.split('/').last) != null;
  }
}
