part of 'drive_repository.dart';

extension _DriveRepositoryMapping on DriveRepository {
  DriveFile _mapFile(Map<String, dynamic> json) {
    final id = '${json['id']}';
    final name = '${json['originalFilename'] ?? json['name'] ?? 'Untitled'}';
    final mime = json['mimeType'] as String?;
    final kind = detectFileKind(name, mime);
    final uploadStatus = '${json['uploadStatus'] ?? 'available'}';
    final storageMode = '${json['storageMode'] ?? 'client_managed'}';
    final mediaAccessMode = '${json['mediaAccessMode'] ?? 'server_proxy'}';
    final thumbnailStatus = '${json['thumbnailStatus'] ?? ''}';
    final previewStatus = '${json['previewStatus'] ?? ''}';
    final thumbnailVersion = (json['thumbnailVersion'] as num?)?.toInt();
    final previewVersion = (json['previewVersion'] as num?)?.toInt();
    final media = kind == FileKind.image || kind == FileKind.video;
    final thumbnailOk =
        uploadStatus == 'available' &&
        ((kind == FileKind.image &&
                thumbnailStatus != 'pending' &&
                thumbnailStatus != 'processing') ||
            (kind == FileKind.video && thumbnailStatus == 'available') ||
            (media && thumbnailStatus == 'available'));
    final previewOk = kind == FileKind.image && previewStatus == 'available';
    final serverProxy =
        mediaAccessMode == 'server_proxy' && storageMode != 'client_managed';
    final thumb =
        json['thumbnailUrl'] as String? ??
        (thumbnailOk && serverProxy
            ? api.mediaUrl(
                '/files/$id/thumbnail',
                params: {'v': thumbnailVersion},
              )
            : null);
    final preview =
        json['previewUrl'] as String? ??
        (previewOk && serverProxy
            ? api.mediaUrl('/files/$id/preview', params: {'v': previewVersion})
            : null);
    return DriveFile(
      id: id,
      name: name,
      kind: kind,
      size: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      modifiedAt: '${json['updatedAt'] ?? DateTime.now().toIso8601String()}',
      createdAt: '${json['createdAt'] ?? DateTime.now().toIso8601String()}',
      parentId: json['folderId'] == null ? null : '${json['folderId']}',
      starred: json['isStarred'] == true,
      shared: json['isShared'] == true,
      mimeType: mime,
      uploadStatus: uploadStatus,
      uploadError: json['uploadError'] as String?,
      storageMode: storageMode,
      uploadOrigin: '${json['uploadOrigin'] ?? 'client_tdlib'}',
      publicProxyStatus: json['publicProxyStatus'] as String?,
      verificationStatus: json['verificationStatus'] as String?,
      mediaAccessMode: mediaAccessMode,
      originalRefAvailable: json['originalRefAvailable'] == true,
      thumbnailRefAvailable: json['thumbnailRefAvailable'] == true,
      previewRefAvailable: json['previewRefAvailable'] == true,
      thumbnailStatus: thumbnailStatus,
      previewStatus: previewStatus,
      thumbnailVersion: thumbnailVersion,
      previewVersion: previewVersion,
      widthPx: (json['widthPx'] as num?)?.toInt(),
      heightPx: (json['heightPx'] as num?)?.toInt(),
      duration: (json['durationSeconds'] as num?)?.toInt(),
      thumbnailUrl: thumb ?? preview,
      previewUrl: preview ?? thumb,
      streamUrl:
          json['streamUrl'] as String? ??
          (media && serverProxy ? api.mediaUrl('/files/$id/stream') : null),
      downloadUrl:
          json['downloadUrl'] as String? ??
          (serverProxy ? api.mediaUrl('/files/$id/download') : null),
    );
  }

  DriveFolder _mapFolder(Map<String, dynamic> json) => DriveFolder(
    id: '${json['id']}',
    name: '${json['name'] ?? 'Folder'}',
    parentId: json['parentId'] == null ? null : '${json['parentId']}',
    modifiedAt: '${json['updatedAt'] ?? DateTime.now().toIso8601String()}',
    createdAt: '${json['createdAt'] ?? DateTime.now().toIso8601String()}',
    starred: json['isStarred'] == true,
    shared: json['isShared'] == true,
    recursiveFileCount: (json['recursiveFileCount'] as num?)?.toInt() ?? 0,
    recursiveSize:
        (json['recursiveSizeBytes'] as num?)?.toInt() ??
        (json['recursiveSize'] as num?)?.toInt() ??
        0,
  );
}
