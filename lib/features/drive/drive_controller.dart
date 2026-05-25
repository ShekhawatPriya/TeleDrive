import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/storage/local_preferences.dart';
import '../../core/utils/file_type_detector.dart';
import '../../core/utils/iterable_ext.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';
import '../profile/app_settings_controller.dart';
import 'drive_repository.dart';

part 'drive_controller/drive_mutations.dart';
part 'drive_controller/drive_refresh.dart';

final localPreferencesProvider = Provider<LocalPreferences>(
  (ref) => LocalPreferences(),
);
final driveRepositoryProvider = Provider<DriveRepository>(
  (ref) => DriveRepository(ref.watch(apiClientProvider)),
);
final driveControllerProvider = ChangeNotifierProvider<DriveController>((ref) {
  return DriveController(
    ref.watch(driveRepositoryProvider),
    ref.watch(localPreferencesProvider),
    ref.read(appSettingsControllerProvider),
    ref.read(authControllerProvider),
  );
});

class DriveFolderViewSnapshot {
  const DriveFolderViewSnapshot({
    required this.folderId,
    required this.folder,
    required this.folders,
    required this.files,
    required this.path,
    required this.loading,
    required this.error,
  });

  final String? folderId;
  final DriveFolder? folder;
  final List<DriveFolder> folders;
  final List<DriveFile> files;
  final List<DriveFolder> path;
  final bool loading;
  final String? error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveFolderViewSnapshot) return false;
    if (other.folderId != folderId) return false;
    if (other.folder != folder) return false;
    if (other.loading != loading) return false;
    if (other.error != error) return false;
    if (!identical(other.folders, folders)) return false;
    if (!identical(other.files, files)) return false;
    if (other.path.length != path.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (other.path[i].id != path[i].id ||
          other.path[i].name != path[i].name ||
          other.path[i].parentId != path[i].parentId) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    folderId,
    folder,
    identityHashCode(folders),
    identityHashCode(files),
    loading,
    error,
    path.length,
  );
}

class DriveRecentsSnapshot {
  const DriveRecentsSnapshot(this.files);
  final List<DriveFile> files;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveRecentsSnapshot) return false;
    if (other.files.length != files.length) return false;
    for (var i = 0; i < files.length; i++) {
      if (other.files[i].id != files[i].id ||
          other.files[i].lastAccessedAt != files[i].lastAccessedAt) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    var h = files.length;
    for (final f in files) {
      h = Object.hash(h, f.id, f.lastAccessedAt);
    }
    return h;
  }
}

class DriveController extends ChangeNotifier {
  DriveController(this._repo, this._prefs, this._settings, this._auth) {
    _loadRecent();
  }

  final DriveRepository _repo;
  final LocalPreferences _prefs;
  final AppSettingsController _settings;
  final AuthController _auth;
  DriveState state = const DriveState();
  Map<String, String> _recent = {};
  Future<void>? _refreshing;
  DateTime? _lastRefreshCompletedAt;
  final Set<String?> _staleFolderIds = {};

  Map<String, DriveFolder> _folderById = const {};
  Map<String, DriveFile> _fileById = const {};
  Map<String, DriveFile> _mediaFileById = const {};
  Map<String?, List<DriveFolder>> _foldersByParent = const {};
  Map<String?, List<DriveFile>> _filesByParent = const {};
  List<DriveFile> _filesMerged = const [];
  List<DriveFile> _mediaFilesMerged = const [];
  List<DriveFile>? _lastFilesRef;
  List<DriveFile>? _lastMediaRef;
  List<DriveFolder>? _lastFoldersRef;
  Map<String, String>? _lastRecentRef;

  void _rebuildIndexesIfDirty() {
    final filesDirty = !identical(_lastFilesRef, state.files);
    final mediaDirty = !identical(_lastMediaRef, state.mediaFiles);
    final foldersDirty = !identical(_lastFoldersRef, state.folders);
    final recentDirty = !identical(_lastRecentRef, _recent);
    if (!filesDirty && !mediaDirty && !foldersDirty && !recentDirty) return;
    if (filesDirty || recentDirty) {
      final fileById = <String, DriveFile>{};
      final filesByParent = <String?, List<DriveFile>>{};
      final merged = <DriveFile>[];
      for (final f in state.files) {
        final mergedFile = _recent.containsKey(f.id)
            ? f.copyWith(lastAccessedAt: _recent[f.id])
            : f;
        merged.add(mergedFile);
        fileById[mergedFile.id] = mergedFile;
        (filesByParent[mergedFile.parentId] ??= <DriveFile>[]).add(mergedFile);
      }
      _filesMerged = merged;
      _fileById = fileById;
      _filesByParent = _preservePerParentIdentity<String?, DriveFile>(
        previous: _filesByParent,
        next: filesByParent,
        equal: _filesEqual,
      );
    }
    if (mediaDirty || recentDirty) {
      final mediaById = <String, DriveFile>{};
      final merged = <DriveFile>[];
      for (final f in state.mediaFiles) {
        final mergedFile = _recent.containsKey(f.id)
            ? f.copyWith(lastAccessedAt: _recent[f.id])
            : f;
        merged.add(mergedFile);
        mediaById[mergedFile.id] = mergedFile;
      }
      _mediaFilesMerged = merged;
      _mediaFileById = mediaById;
    }
    if (foldersDirty) {
      final folderById = <String, DriveFolder>{};
      final foldersByParent = <String?, List<DriveFolder>>{};
      for (final f in state.folders) {
        folderById[f.id] = f;
        (foldersByParent[f.parentId] ??= <DriveFolder>[]).add(f);
      }
      _folderById = folderById;
      _foldersByParent = _preservePerParentIdentity<String?, DriveFolder>(
        previous: _foldersByParent,
        next: foldersByParent,
        equal: _foldersEqual,
      );
    }
    _lastFilesRef = state.files;
    _lastMediaRef = state.mediaFiles;
    _lastFoldersRef = state.folders;
    _lastRecentRef = _recent;
  }

  static Map<K, List<V>> _preservePerParentIdentity<K, V>({
    required Map<K, List<V>> previous,
    required Map<K, List<V>> next,
    required bool Function(V a, V b) equal,
  }) {
    if (previous.isEmpty || next.isEmpty) return next;
    final preserved = Map<K, List<V>>.of(next);
    for (final key in next.keys) {
      final old = previous[key];
      if (old == null) continue;
      final cur = next[key]!;
      if (identical(old, cur)) continue;
      if (old.length != cur.length) continue;
      var same = true;
      for (var i = 0; i < cur.length; i++) {
        if (!equal(old[i], cur[i])) {
          same = false;
          break;
        }
      }
      if (same) preserved[key] = old;
    }
    return preserved;
  }

  static bool _filesEqual(DriveFile a, DriveFile b) =>
      identical(a, b) ||
      (a.id == b.id &&
          a.name == b.name &&
          a.parentId == b.parentId &&
          a.kind == b.kind &&
          a.size == b.size &&
          a.modifiedAt == b.modifiedAt &&
          a.createdAt == b.createdAt &&
          a.starred == b.starred &&
          a.shared == b.shared &&
          a.mimeType == b.mimeType &&
          a.uploadStatus == b.uploadStatus &&
          a.uploadError == b.uploadError &&
          a.thumbnailUrl == b.thumbnailUrl &&
          a.previewUrl == b.previewUrl &&
          a.streamUrl == b.streamUrl &&
          a.downloadUrl == b.downloadUrl &&
          a.localUri == b.localUri &&
          a.thumbnailStatus == b.thumbnailStatus &&
          a.previewStatus == b.previewStatus &&
          a.thumbnailVersion == b.thumbnailVersion &&
          a.previewVersion == b.previewVersion &&
          a.widthPx == b.widthPx &&
          a.heightPx == b.heightPx &&
          a.duration == b.duration &&
          a.lastAccessedAt == b.lastAccessedAt &&
          a.isOptimistic == b.isOptimistic &&
          a.localId == b.localId);

  static bool _foldersEqual(DriveFolder a, DriveFolder b) =>
      identical(a, b) ||
      (a.id == b.id &&
          a.name == b.name &&
          a.parentId == b.parentId &&
          a.modifiedAt == b.modifiedAt &&
          a.createdAt == b.createdAt &&
          a.starred == b.starred &&
          a.shared == b.shared &&
          a.recursiveFileCount == b.recursiveFileCount &&
          a.recursiveSize == b.recursiveSize &&
          a.isOptimistic == b.isOptimistic &&
          a.uploadError == b.uploadError);

  void setActiveFolderId(String? folderId) {
    if (state.activeFolderId == folderId) return;
    state = state.copyWith(activeFolderId: folderId);
    _notifyListeners();

    if (_staleFolderIds.contains(folderId)) {
      refresh(silent: true, force: true);
    }
  }

  Future<void> resetForAccountSwitch() async {
    state = const DriveState(loading: true);
    _recent = {};
    _refreshing = null;
    _lastRefreshCompletedAt = null;
    _staleFolderIds.clear();
    _notifyListeners();
    await _loadRecent();
  }

  List<DriveFile> get files {
    _rebuildIndexesIfDirty();
    return _filesMerged;
  }

  List<DriveFile> get mediaFiles {
    _rebuildIndexesIfDirty();
    return _mediaFilesMerged;
  }

  List<DriveFolder> get folders => state.folders;

  Future<void> refresh({bool silent = false, bool force = false}) async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    if (!force && silent && _lastRefreshCompletedAt != null) {
      final elapsed = DateTime.now().difference(_lastRefreshCompletedAt!);
      if (elapsed < const Duration(seconds: 1)) return;
    }
    final refresh = _refresh(silent: silent);
    _refreshing = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshing, refresh)) {
        _refreshing = null;
      }
    }
  }

  void applyDriveState(DriveSnapshot snapshot, {bool notify = true}) {
    final incomingFiles = snapshot.files
        .where((f) => f.uploadStatus == 'available')
        .toList();
    final incomingMedia = snapshot.mediaFiles
        .where((f) => f.uploadStatus == 'available')
        .toList();

    final updatedFiles = _reconcileFiles(
      existing: state.files,
      incoming: incomingFiles,
      authoritative: true,
    );
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: incomingMedia,
      authoritative: true,
    );

    final keptOptimisticFolders = state.folders
        .where((f) => f.isOptimistic)
        .toList();
    final folderIds = <String>{};
    final reconciledFolders = <DriveFolder>[];
    for (final f in [...keptOptimisticFolders, ...snapshot.folders]) {
      if (folderIds.add(f.id)) {
        reconciledFolders.add(f);
      }
    }

    state = state.copyWith(
      files: updatedFiles,
      mediaFiles: updatedMedia,
      folders: reconciledFolders,
      mediaCursor: snapshot.mediaCursor,
      loading: false,
      clearError: true,
    );
    _lastRefreshCompletedAt = DateTime.now();
    if (notify) notifyListeners();
  }

  Future<void> loadMoreMedia() async {
    if (state.mediaCursor == null || state.loadingMoreMedia) return;
    state = state.copyWith(loadingMoreMedia: true);
    notifyListeners();
    try {
      final page = await _repo.listFiles(
        type: 'media',
        cursor: state.mediaCursor,
        limit: 60,
        allFolders: true,
      );
      final ids = state.mediaFiles.map((f) => f.id).toSet();
      state = state.copyWith(
        mediaFiles: [
          ...state.mediaFiles,
          ...page.files.where((f) => !ids.contains(f.id)),
        ],
        mediaCursor: page.nextCursor,
        loadingMoreMedia: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMoreMedia: false);
    }
    notifyListeners();
  }

  List<DriveFile> filesInFolder(String? folderId) {
    _rebuildIndexesIfDirty();
    return _filesByParent[folderId] ?? const [];
  }

  List<DriveFolder> foldersInFolder(String? folderId) {
    _rebuildIndexesIfDirty();
    return _foldersByParent[folderId] ?? const [];
  }

  DriveFile? file(String id) {
    _rebuildIndexesIfDirty();
    return _fileById[id];
  }

  DriveFile? anyFile(String id) {
    _rebuildIndexesIfDirty();
    return _fileById[id] ?? _mediaFileById[id];
  }

  DriveFolder? folder(String id) {
    _rebuildIndexesIfDirty();
    return _folderById[id];
  }

  DriveFolderViewSnapshot folderViewSnapshot(String? folderId) {
    _rebuildIndexesIfDirty();
    final folder = folderId == null ? null : _folderById[folderId];
    final folders = _foldersByParent[folderId] ?? const <DriveFolder>[];
    final files = _filesByParent[folderId] ?? const <DriveFile>[];
    final path = folderId == null
        ? const <DriveFolder>[]
        : folderPath(folderId);
    return DriveFolderViewSnapshot(
      folderId: folderId,
      folder: folder,
      folders: folders,
      files: files,
      path: path,
      loading: state.loading,
      error: state.error,
    );
  }

  DriveRecentsSnapshot recentsSnapshot() {
    _rebuildIndexesIfDirty();
    final result = <DriveFile>[];
    for (final f in _filesMerged) {
      if (f.lastAccessedAt != null) result.add(f);
    }
    result.sort((a, b) => b.lastAccessedAt!.compareTo(a.lastAccessedAt!));
    if (result.length > 5) result.length = 5;
    return DriveRecentsSnapshot(List<DriveFile>.unmodifiable(result));
  }

  void markShared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    state = state.copyWith(
      files: state.files
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: true) : f)
          .toList(),
      mediaFiles: state.mediaFiles
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: true) : f)
          .toList(),
      folders: state.folders
          .map((f) => folderIds.contains(f.id) ? f.copyWith(shared: true) : f)
          .toList(),
    );
    notifyListeners();
  }

  void markUnshared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    state = state.copyWith(
      files: state.files
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: false) : f)
          .toList(),
      mediaFiles: state.mediaFiles
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: false) : f)
          .toList(),
      folders: state.folders
          .map((f) => folderIds.contains(f.id) ? f.copyWith(shared: false) : f)
          .toList(),
    );
    notifyListeners();
  }

  List<DriveFolder> folderPath(String id) {
    final path = <DriveFolder>[];
    DriveFolder? current = folder(id);
    while (current != null) {
      path.insert(0, current);
      current = current.parentId == null ? null : folder(current.parentId!);
    }
    return path;
  }

  List<DriveFile> recentFiles() {
    final result = files.where((f) => f.lastAccessedAt != null).toList()
      ..sort((a, b) => b.lastAccessedAt!.compareTo(a.lastAccessedAt!));
    return result.take(5).toList();
  }

  List<DriveFile> photoFiles(String filter) {
    final list = [...mediaFiles.where(isMediaFile)]
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return switch (filter) {
      'images' => list.where(isImageFile).toList(),
      'videos' => list.where(isVideoFile).toList(),
      'starred' => list.where((f) => f.starred).toList(),
      _ => list,
    };
  }

  ({List<DriveFile> files, List<DriveFolder> folders}) starred() {
    return (
      files: files.where((f) => f.starred).toList(),
      folders: folders.where((f) => f.starred).toList(),
    );
  }

  Future<DriveFolder> createFolder(String name, String? parentId) =>
      _createFolder(name, parentId);

  Future<void> renameFolder(String id, String name) => _renameFolder(id, name);

  Future<void> moveFile(String fileId, String? targetFolderId) =>
      _moveFile(fileId, targetFolderId);

  Future<void> moveFolder(String folderId, String? targetParentId) =>
      _moveFolder(folderId, targetParentId);

  Future<void> deleteItems({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
  }) => _deleteItems(fileIds: fileIds, folderIds: folderIds);

  Future<void> restoreFile(String id) async {
    await _repo.restoreFile(id);
    _bumpTrashRevision();
    await refresh(silent: true, force: true);
  }

  Future<void> restoreFolder(String id) async {
    await _repo.restoreFolder(id);
    _bumpTrashRevision();
    await refresh(silent: true, force: true);
  }

  Future<void> purgeFile(String id) async {
    await _repo.purgeFile(id);
    _bumpTrashRevision();
    await refresh(silent: true, force: true);
  }

  Future<void> purgeFolder(String id) async {
    await _repo.purgeFolder(id);
    _bumpTrashRevision();
    await refresh(silent: true, force: true);
  }

  Future<void> purgeAllTrash() async {
    await _repo.purgeAllTrash();
    _bumpTrashRevision();
    await refresh(silent: true, force: true);
  }

  Future<void> archiveFile(String id) =>
      _moveToShelf(id, kind: _ShelfKind.archive, archive: true);

  Future<void> unarchiveFile(String id) =>
      _moveToShelf(id, kind: _ShelfKind.archive, archive: false);

  Future<void> lockFile(String id) =>
      _moveToShelf(id, kind: _ShelfKind.locked, archive: true);

  Future<void> unlockFile(String id) =>
      _moveToShelf(id, kind: _ShelfKind.locked, archive: false);

  Future<void> toggleStar(String id, {bool folder = false}) =>
      _toggleStar(id, folder: folder);

  Future<void> markAccessed(String id) async {
    _recent = {..._recent, id: DateTime.now().toIso8601String()};
    await _prefs.setRecentAccess(_recent, userId: _auth.activeAccount?.userId);
    notifyListeners();
  }

  void _notifyListeners() {
    notifyListeners();
  }

  void syncOptimisticUploads(List<DriveFile> optimistic) {
    final keep = optimistic
        .where((f) => f.uploadStatus != 'cancelled')
        .toList();
    final updatedFiles = _reconcileFiles(
      existing: state.files,
      incoming: keep,
      removeOrphanedOptimistic: true,
    );

    final keepMedia = keep.where(isMediaFile).toList();
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: keepMedia,
      removeOrphanedOptimistic: true,
    );

    final filesUnchanged =
        _filesFingerprint(updatedFiles) == _filesFingerprint(state.files);
    final mediaUnchanged =
        _filesFingerprint(updatedMedia) == _filesFingerprint(state.mediaFiles);
    if (filesUnchanged && mediaUnchanged) return;

    state = state.copyWith(files: updatedFiles, mediaFiles: updatedMedia);
    notifyListeners();
  }

  int _filesFingerprint(List<DriveFile> files) {
    if (files.isEmpty) return 0;
    var h = 0;
    for (final f in files) {
      h = Object.hash(
        h,
        f.id,
        f.name,
        f.parentId,
        f.kind,
        f.size,
        f.modifiedAt,
        f.createdAt,
        f.starred,
        f.shared,
        f.mimeType,
        f.uploadStatus,
        f.uploadError,
        Object.hash(
          f.thumbnailUrl,
          f.previewUrl,
          f.streamUrl,
          f.downloadUrl,
          f.localUri,
          f.thumbnailStatus,
          f.previewStatus,
          f.thumbnailVersion,
          f.previewVersion,
          f.widthPx,
          f.heightPx,
          f.duration,
          f.lastAccessedAt,
          f.isOptimistic,
          f.localId,
        ),
      );
    }
    return h;
  }

  void _bumpTrashRevision() {
    state = state.copyWith(trashRevision: state.trashRevision + 1);
    notifyListeners();
  }

  Set<String> _descendantFolderIds(String folderId) {
    final found = <String>{};
    void visit(String id) {
      for (final child in state.folders.where((f) => f.parentId == id)) {
        if (found.add(child.id)) visit(child.id);
      }
    }

    visit(folderId);
    return found;
  }
}
