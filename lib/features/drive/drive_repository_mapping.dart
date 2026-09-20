part of 'drive_repository.dart';

extension _DriveRepositoryMapping on DriveRepository {
  DriveFile _mapFile(Map<String, dynamic> json) {
    final id = _readString(json, const ['id']) ?? '${json['id']}';
    final name =
        _readString(json, const ['originalFilename', 'original_filename']) ??
        _readString(json, const ['name']) ??
        'Untitled';
    final mime = _readString(json, const ['mimeType', 'mime_type']);
    final kind = detectFileKind(name, mime);
    final uploadStatus =
        _readString(json, const ['uploadStatus', 'upload_status']) ??
        'available';
    final storageMode = _readString(json, const [
      'storageMode',
      'storage_mode',
    ]);
    final mediaAccessMode = _readString(json, const [
      'mediaAccessMode',
      'media_access_mode',
    ]);
    final thumbnailStatus = _readString(json, const [
      'thumbnailStatus',
      'thumbnail_status',
    ]);
    final previewStatus = _readString(json, const [
      'previewStatus',
      'preview_status',
    ]);
    final thumbnailVersion = _readInt(json, const [
      'thumbnailVersion',
      'thumbnail_version',
    ]);
    final previewVersion = _readInt(json, const [
      'previewVersion',
      'preview_version',
    ]);
    final media = kind == FileKind.image || kind == FileKind.video;
    final thumbnailOk =
        uploadStatus == 'available' &&
        ((kind == FileKind.image &&
                thumbnailStatus != 'pending' &&
                thumbnailStatus != 'processing' &&
                thumbnailStatus != 'failed' &&
                thumbnailStatus != 'unavailable') ||
            (media && thumbnailStatus == 'available'));
    final previewOk = kind == FileKind.image && previewStatus == 'available';
    final serverProxy = _isServerProxyCompatible(storageMode, mediaAccessMode);
    final explicitThumb = _readString(json, const [
      'thumbnailUrl',
      'thumbnail_url',
    ]);
    final explicitPreview = _readString(json, const [
      'previewUrl',
      'preview_url',
    ]);
    final thumb =
        explicitThumb ??
        (thumbnailOk && serverProxy
            ? api.mediaUrl(
                '/files/$id/thumbnail',
                params: {'v': thumbnailVersion},
              )
            : null);
    final preview =
        explicitPreview ??
        (previewOk && serverProxy
            ? api.mediaUrl('/files/$id/preview', params: {'v': previewVersion})
            : null);
    final streamUrl =
        _readString(json, const ['streamUrl', 'stream_url']) ??
        (media && uploadStatus == 'available' && serverProxy
            ? api.mediaUrl('/files/$id/stream')
            : null);
    final downloadUrl =
        _readString(json, const ['downloadUrl', 'download_url']) ??
        (uploadStatus == 'available' && serverProxy
            ? api.mediaUrl('/files/$id/download')
            : null);
    return DriveFile(
      id: id,
      name: name,
      kind: kind,
      size: _readInt(json, const ['sizeBytes', 'size_bytes']) ?? 0,
      modifiedAt: _readString(json, const ['updatedAt', 'updated_at']) ?? '',
      createdAt: _readString(json, const ['createdAt', 'created_at']) ?? '',
      parentId: _readString(json, const ['folderId', 'folder_id']),
      starred: _readBool(json, const ['isStarred', 'is_starred']) ?? false,
      shared: _readBool(json, const ['isShared', 'is_shared']) ?? false,
      mimeType: mime,
      uploadStatus: uploadStatus,
      uploadError: _readString(json, const ['uploadError', 'upload_error']),
      storageMode: storageMode,
      uploadOrigin:
          _readString(json, const ['uploadOrigin', 'upload_origin']) ??
          'client_tdlib',
      publicProxyStatus: _readString(json, const [
        'publicProxyStatus',
        'public_proxy_status',
      ]),
      verificationStatus: _readString(json, const [
        'verificationStatus',
        'verification_status',
      ]),
      mediaAccessMode: mediaAccessMode,
      originalRefAvailable:
          _readBool(json, const [
            'originalRefAvailable',
            'original_ref_available',
          ]) ??
          false,
      thumbnailRefAvailable:
          _readBool(json, const [
            'thumbnailRefAvailable',
            'thumbnail_ref_available',
          ]) ??
          false,
      previewRefAvailable:
          _readBool(json, const [
            'previewRefAvailable',
            'preview_ref_available',
          ]) ??
          false,
      thumbnailStatus: thumbnailStatus,
      previewStatus: previewStatus,
      thumbnailVersion: thumbnailVersion,
      previewVersion: previewVersion,
      widthPx: _readInt(json, const ['widthPx', 'width_px']),
      heightPx: _readInt(json, const ['heightPx', 'height_px']),
      duration: _readInt(json, const ['durationSeconds', 'duration_seconds']),
      thumbnailUrl: thumb ?? preview,
      previewUrl: preview ?? thumb,
      streamUrl: streamUrl,
      downloadUrl: downloadUrl,
    );
  }

  DriveFolder _mapFolder(Map<String, dynamic> json) => DriveFolder(
    id: _readString(json, const ['id']) ?? '${json['id']}',
    name: _readString(json, const ['name']) ?? 'Folder',
    parentId: _readString(json, const ['parentId', 'parent_id']),
    modifiedAt: _readString(json, const ['updatedAt', 'updated_at']) ?? '',
    createdAt: _readString(json, const ['createdAt', 'created_at']) ?? '',
    starred: _readBool(json, const ['isStarred', 'is_starred']) ?? false,
    shared: _readBool(json, const ['isShared', 'is_shared']) ?? false,
    recursiveFileCount:
        _readInt(json, const ['recursiveFileCount', 'recursive_file_count']) ??
        0,
    recursiveSize:
        _readInt(json, const ['recursiveSizeBytes', 'recursive_size_bytes']) ??
        _readInt(json, const ['recursiveSize', 'recursive_size']) ??
        0,
  );
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final string = value is String ? value : '$value';
    final trimmed = string.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool? _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }
  return null;
}

Map<String, dynamic>? _readMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return null;
}

List<dynamic> _readList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) return value;
  }
  return const [];
}

bool _isServerProxyCompatible(String? storageMode, String? mediaAccessMode) {
  if (storageMode == 'client_managed') return false;
  if (mediaAccessMode == 'client_direct' ||
      mediaAccessMode == 'client_tdlib' ||
      mediaAccessMode == 'telegram_client_direct') {
    return false;
  }
  if (mediaAccessMode == null) return true;
  return mediaAccessMode == 'server_proxy';
}
