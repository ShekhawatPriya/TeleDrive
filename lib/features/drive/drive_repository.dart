import '../../core/network/api_client.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';

class DriveRepository {
  DriveRepository(this.api);

  final ApiClient api;

  Future<({List<DriveFile> files, String? nextCursor})> listFiles({
    String? folderId,
    String type = 'all',
    int limit = 60,
    String? cursor,
    bool allFolders = false,
  }) async {
    final res = await api.dio.get(
      '/files',
      queryParameters: {
        if (!allFolders && folderId != null) 'folder_id': folderId,
        if (allFolders) 'scope': 'all',
        if (type != 'all') 'type': type,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final files = (data['files'] as List? ?? [])
        .map((e) => _mapFile(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (files: files, nextCursor: data['nextCursor'] as String?);
  }

  Future<List<DriveFile>> listAllFiles() async {
    final all = <DriveFile>[];
    String? cursor;
    do {
      final page = await listFiles(
        limit: 100,
        cursor: cursor,
        allFolders: true,
      );
      all.addAll(page.files);
      cursor = page.nextCursor;
    } while (cursor != null);
    return all;
  }

  Future<DriveSnapshot> getDriveState() async {
    final res = await api.dio.get('/frontend/drive-state');
    return parseDriveState(Map<String, dynamic>.from(res.data as Map));
  }

  DriveSnapshot parseDriveState(Map<String, dynamic> data) {
    final files = (data['files'] as List? ?? [])
        .map((e) => _mapFile(Map<String, dynamic>.from(e as Map)))
        .toList();
    final mediaFiles = (data['mediaFiles'] as List? ?? [])
        .map((e) => _mapFile(Map<String, dynamic>.from(e as Map)))
        .toList();
    final folders = (data['folders'] as List? ?? [])
        .map((e) => _mapFolder(Map<String, dynamic>.from(e as Map)))
        .toList();
    return DriveSnapshot(
      files: files,
      mediaFiles: mediaFiles,
      folders: folders,
      mediaCursor: data['mediaNextCursor'] as String?,
    );
  }

  Future<DriveFile> getFile(String id) async {
    final res = await api.dio.get('/files/$id');
    return _mapFile(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<DriveFolder>> listFolders() async {
    final res = await api.dio.get('/folders');
    return (res.data as List? ?? [])
        .map((e) => _mapFolder(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DriveFolder> createFolder(String name, String? parentId) async {
    final res = await api.dio.post(
      '/folders',
      data: {
        'name': name,
        'parent_id': parentId == null ? null : int.parse(parentId),
      },
    );
    return _mapFolder(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> renameFolder(String id, String name) async {
    await api.dio.patch('/folders/$id', data: {'name': name});
  }

  Future<DriveFile> moveFile(String id, String? folderId) async {
    final res = await api.dio.patch(
      '/files/$id',
      data: {'folder_id': folderId == null ? null : int.parse(folderId)},
    );
    return _mapFile(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DriveFolder> moveFolder(String id, String? parentId) async {
    final res = await api.dio.patch(
      '/folders/$id',
      data: {'parent_id': parentId == null ? null : int.parse(parentId)},
    );
    return _mapFolder(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteFile(String id) async =>
      api.dio.delete('/files/$id').then((_) {});
  Future<void> deleteFolder(String id) async =>
      api.dio.delete('/folders/$id').then((_) {});

  Future<DriveFile> setFileStarred(String id, bool starred) async {
    final res = await api.dio.patch(
      '/files/$id',
      data: {'is_starred': starred},
    );
    return _mapFile(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DriveFolder> setFolderStarred(String id, bool starred) async {
    final res = await api.dio.patch(
      '/folders/$id',
      data: {'is_starred': starred},
    );
    return _mapFolder(Map<String, dynamic>.from(res.data as Map));
  }

  DriveFile _mapFile(Map<String, dynamic> json) {
    final id = '${json['id']}';
    final name = '${json['originalFilename'] ?? json['name'] ?? 'Untitled'}';
    final mime = json['mimeType'] as String?;
    final kind = detectFileKind(name, mime);
    final uploadStatus = '${json['uploadStatus'] ?? 'available'}';
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
    final thumb = thumbnailOk
        ? api.mediaUrl('/files/$id/thumbnail', params: {'v': thumbnailVersion})
        : null;
    final preview = previewOk
        ? api.mediaUrl('/files/$id/preview', params: {'v': previewVersion})
        : null;
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
      thumbnailStatus: thumbnailStatus,
      previewStatus: previewStatus,
      thumbnailVersion: thumbnailVersion,
      previewVersion: previewVersion,
      widthPx: (json['widthPx'] as num?)?.toInt(),
      heightPx: (json['heightPx'] as num?)?.toInt(),
      duration: (json['durationSeconds'] as num?)?.toInt(),
      thumbnailUrl: thumb ?? preview,
      previewUrl: preview ?? thumb,
      streamUrl: media ? api.mediaUrl('/files/$id/stream') : null,
      downloadUrl: api.mediaUrl('/files/$id/download'),
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
