import '../../core/media/gallery_media_scanner.dart';
import '../../core/network/api_client.dart';
import '../../core/telegram/telegram_client_models.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import 'drive_repository_models.dart';

export 'drive_repository_models.dart';

part 'drive_repository_mapping.dart';

class DriveRepository {
  DriveRepository(this.api);

  final ApiClient api;

  Future<Map<String, FreeUpSpaceResolveDecision>> resolveFreeUpSpaceCandidates(
    List<GalleryMediaAsset> assets,
  ) async {
    final decisions = <String, FreeUpSpaceResolveDecision>{};
    const chunkSize = 200;
    for (var start = 0; start < assets.length; start += chunkSize) {
      final chunk = assets.skip(start).take(chunkSize).toList();
      final res = await api.dio.post(
        '/client-backup-assets/free-up-space/resolve',
        data: {
          'assets': chunk
              .map(
                (asset) => {
                  'fingerprint': asset.fingerprint,
                  'content_uri': asset.contentUri,
                  'display_name': asset.name,
                  'size_bytes': asset.sizeBytes,
                  'media_type': asset.mediaType,
                  'mime_type': asset.mimeType,
                  'modified_at_millis': asset.modifiedAtMillis,
                  'added_at_millis': asset.addedAtMillis,
                  'relative_path': asset.relativePath,
                  'source_kind': asset.sourceKind,
                },
              )
              .toList(),
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final rows = (data['assets'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(FreeUpSpaceResolveDecision.fromJson);
      for (final row in rows) {
        if (row.fingerprint.isNotEmpty) decisions[row.fingerprint] = row;
      }
    }
    return decisions;
  }

  Future<({List<DriveFile> files, String? nextCursor})> listFiles({
    String? folderId,
    String type = 'all',
    int limit = 60,
    String? cursor,
    bool allFolders = false,
    String? query,
  }) async {
    final res = await api.dio.get(
      '/files',
      queryParameters: {
        if (!allFolders && folderId != null) 'folder_id': folderId,
        if (allFolders) 'scope': 'all',
        if (type != 'all') 'type': type,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final files = _readList(data, const [
      'files',
    ]).map((e) => _mapFile(Map<String, dynamic>.from(e as Map))).toList();
    return (
      files: files,
      nextCursor: _readString(data, const ['nextCursor', 'next_cursor']),
    );
  }

  Future<
    ({List<DriveFolder> folders, String? nextCursor, List<DriveFolder> path})
  >
  listFolderChildren({
    String? parentId,
    int limit = 200,
    String? cursor,
  }) async {
    final res = await api.dio.get(
      '/folders/children',
      queryParameters: {
        if (parentId != null) 'parent_id': parentId,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final folders = _readList(data, const [
      'folders',
    ]).map((e) => _mapFolder(Map<String, dynamic>.from(e as Map))).toList();
    final path = _readList(data, const [
      'path',
    ]).map((e) => _mapFolder(Map<String, dynamic>.from(e as Map))).toList();
    return (
      folders: folders,
      nextCursor: _readString(data, const ['nextCursor', 'next_cursor']),
      path: path,
    );
  }

  Future<({List<DriveFile> files, String? nextCursor})> listStarredFiles({
    int limit = 60,
    String? cursor,
  }) async {
    final res = await api.dio.get(
      '/files/starred',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final files = _readList(data, const [
      'files',
    ]).map((e) => _mapFile(Map<String, dynamic>.from(e as Map))).toList();
    return (
      files: files,
      nextCursor: _readString(data, const ['nextCursor', 'next_cursor']),
    );
  }

  Future<({List<DriveFolder> folders, String? nextCursor})> listStarredFolders({
    int limit = 200,
    String? cursor,
  }) async {
    final res = await api.dio.get(
      '/folders/starred',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final folders = _readList(data, const [
      'folders',
    ]).map((e) => _mapFolder(Map<String, dynamic>.from(e as Map))).toList();
    return (
      folders: folders,
      nextCursor: _readString(data, const ['nextCursor', 'next_cursor']),
    );
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

  Future<List<DriveFile>> listTrashFiles() async {
    final res = await api.dio.get('/files/trash');
    final raw = res.data;
    final files = raw is Map ? raw['files'] : raw;
    return (files as List? ?? [])
        .map((e) => _mapFile(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DriveFile>> listArchiveFiles() async {
    final res = await api.dio.get('/files/archive');
    final raw = res.data;
    final files = raw is Map ? raw['files'] : raw;
    return (files as List? ?? [])
        .map((e) => _mapFile(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DriveFile>> listLockedFiles() async {
    final res = await api.dio.get('/files/locked');
    final raw = res.data;
    final files = raw is Map ? raw['files'] : raw;
    return (files as List? ?? [])
        .map((e) => _mapFile(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DriveSnapshot> getDriveState() async {
    final res = await api.dio.get('/frontend/drive-state');
    return parseDriveState(Map<String, dynamic>.from(res.data as Map));
  }

  DriveSnapshot parseDriveState(Map<String, dynamic> data) {
    final files = _readList(data, const [
      'files',
    ]).map((e) => _mapFile(Map<String, dynamic>.from(e as Map))).toList();
    final mediaFiles = _readList(data, const [
      'mediaFiles',
      'media_files',
    ]).map((e) => _mapFile(Map<String, dynamic>.from(e as Map))).toList();
    final folders = _readList(data, const [
      'folders',
    ]).map((e) => _mapFolder(Map<String, dynamic>.from(e as Map))).toList();
    return DriveSnapshot(
      files: files,
      mediaFiles: mediaFiles,
      folders: folders,
      mediaCursor: _readString(data, const [
        'mediaNextCursor',
        'media_next_cursor',
      ]),
      rootFileCursor: _readString(data, const [
        'rootFileCursor',
        'root_file_cursor',
      ]),
      rootFolderCursor: _readString(data, const [
        'rootFolderCursor',
        'root_folder_cursor',
      ]),
    );
  }

  Future<DriveFile> getFile(String id) async {
    final res = await api.dio.get('/files/$id');
    return _mapFile(Map<String, dynamic>.from(res.data as Map));
  }

  Future<({TelegramMediaRef? ref, String? fallbackUrl, String cacheKey})>
  mediaRef(String id, {String variant = 'original'}) async {
    final res = await api.dio.get(
      '/files/$id/media-ref',
      queryParameters: {'variant': variant},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawRef = _readMap(data, const ['telegramRef', 'telegram_ref']);
    return (
      ref: rawRef == null ? null : TelegramMediaRef.fromJson(rawRef),
      fallbackUrl: _readString(data, const ['fallbackUrl', 'fallback_url']),
      cacheKey:
          _readString(data, const ['cacheKey', 'cache_key']) ?? '$id:$variant',
    );
  }

  Future<List<DriveFolder>> listFolders() async {
    final res = await api.dio.get('/folders');
    return (res.data as List? ?? [])
        .map((e) => _mapFolder(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DriveFolder>> listTrashFolders() async {
    final res = await api.dio.get('/folders/trash');
    final raw = res.data;
    final folders = raw is Map ? raw['folders'] : raw;
    return (folders as List? ?? [])
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

  Future<DriveFolder> ensureFolderPath(List<String> path) async {
    final res = await api.dio.post(
      '/folders/ensure-path',
      data: {'path': path},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawFolder = data['folder'] ?? data['finalFolder'] ?? data;
    return _mapFolder(Map<String, dynamic>.from(rawFolder as Map));
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
  Future<void> purgeFile(String id) async =>
      api.dio.delete('/files/$id/purge').then((_) {});
  Future<void> purgeFolder(String id) async =>
      api.dio.delete('/folders/$id/purge').then((_) {});
  Future<void> restoreFile(String id) async =>
      api.dio.post('/files/$id/restore').then((_) {});
  Future<void> restoreFolder(String id) async =>
      api.dio.post('/folders/$id/restore').then((_) {});

  Future<void> archiveFile(String id) async =>
      api.dio.post('/files/$id/archive').then((_) {});
  Future<void> unarchiveFile(String id) async =>
      api.dio.post('/files/$id/unarchive').then((_) {});
  Future<void> lockFile(String id) async =>
      api.dio.post('/files/$id/lock').then((_) {});
  Future<void> unlockFile(String id) async =>
      api.dio.post('/files/$id/unlock').then((_) {});

  Future<void> purgeAllTrash() async {
    final results = await Future.wait([listTrashFiles(), listTrashFolders()]);
    final files = results[0] as List<DriveFile>;
    final folders = results[1] as List<DriveFolder>;
    await Future.wait([
      ...folders.map((f) => purgeFolder(f.id)),
      ...files.map((f) => purgeFile(f.id)),
    ]);
  }

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
}
