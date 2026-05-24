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
  final String? path;
  final String? relativePath;
  final int? durationMs;

  String get stableKey => '$id:$sizeBytes:$modifiedAtMillis';

  factory GalleryMediaAsset.fromJson(Map<String, dynamic> json) {
    return GalleryMediaAsset(
      id: '${json['id']}',
      contentUri: '${json['contentUri']}',
      name: '${json['name'] ?? 'media'}',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: '${json['mimeType'] ?? 'application/octet-stream'}',
      mediaType: '${json['mediaType'] ?? 'image'}',
      modifiedAtMillis: (json['modifiedAtMillis'] as num?)?.toInt() ?? 0,
      path: json['path'] as String?,
      relativePath: json['relativePath'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }
}

class GalleryMediaScanner {
  const GalleryMediaScanner({MethodChannel? mediaChannel})
    : _mediaChannel = mediaChannel ?? const MethodChannel('teledrive/media');

  final MethodChannel _mediaChannel;

  Future<List<GalleryMediaAsset>> listRecent({
    int limit = 100,
    bool includeImages = true,
    bool includeVideos = true,
  }) async {
    final result = await _mediaChannel.invokeListMethod<Object?>(
      'listGalleryMedia',
      {
        'limit': limit,
        'includeImages': includeImages,
        'includeVideos': includeVideos,
      },
    );
    return (result ?? const [])
        .whereType<Map>()
        .map(
          (item) => GalleryMediaAsset.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((asset) => asset.sizeBytes > 0 && asset.contentUri.isNotEmpty)
        .toList();
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
}
