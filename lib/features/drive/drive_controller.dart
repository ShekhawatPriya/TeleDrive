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
part 'drive_controller/drive_delete_mutations.dart';
part 'drive_controller/drive_star_mutations.dart';
part 'drive_controller/drive_shelf_mutations.dart';
part 'drive_controller/drive_refresh.dart';
part 'drive_controller/drive_snapshots.dart';
part 'drive_controller/drive_indexes.dart';
part 'drive_controller/drive_folder_loading.dart';
part 'drive_controller/drive_state_bootstrap.dart';
part 'drive_controller/drive_starred.dart';
part 'drive_controller/drive_queries.dart';
part 'drive_controller/drive_share_updates.dart';
part 'drive_controller/drive_optimistic_sync.dart';
part 'drive_controller/drive_folder_helpers.dart';
part 'drive_controller/drive_file_fetch.dart';

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
  // Generation tokens guard against stale folder fetches racing with newer
  // ones (G5). Each ensureFolderLoaded / refreshFolder / loadMoreFolder call
  // bumps the gen for that folder; on response, if the gen has advanced the
  // response is dropped.
  final Map<String?, int> _folderLoadGen = {};
  int _starredLoadGen = 0;
  // Dedupes concurrent `ensureFileLoaded(id)` calls so search/starred/recents
  // taps for the same file id don't issue parallel /files/{id} requests.
  final Map<String, Future<DriveFile?>> _fileFetches = {};
  // Loose file metadata cache for files resolved via /files/{id} that aren't
  // currently in any loaded folder page. Persists across `_refreshFlatAggregates`
  // (which is rebuilt from folder pages) so a starred/search-tap stays openable
  // after the user navigates away. Cleared on account switch.
  final Map<String, DriveFile> _resolvedFiles = {};

  // Global folder metadata cache. Populated from every folder we encounter
  // (root bootstrap, child listings, paths from G4, mutations). Intentionally
  // partial — folder views must NOT use this as proof of contents, only for
  // breadcrumb / metadata lookup.
  Map<String, DriveFolder> _folderById = const {};
  Map<String, DriveFile> _fileById = const {};
  Map<String, DriveFile> _mediaFileById = const {};
  // Derived flat aggregates kept in sync with [DriveState.folderPages] +
  // optimistic items. Used only by upload-compat code (G1 keeps upload paths
  // unchanged) and search. Folder views read from `folderPages` directly.
  List<DriveFile> _filesMerged = const [];
  List<DriveFile> _mediaFilesMerged = const [];
  List<DriveFile>? _lastFilesRef;
  List<DriveFile>? _lastMediaRef;
  List<DriveFolder>? _lastFoldersRef;
  Map<String, String>? _lastRecentRef;

  void setActiveFolderId(String? folderId) => _setActiveFolderId(folderId);

  Future<void> resetForAccountSwitch() => _resetForAccountSwitch();

  List<DriveFile> get files {
    _rebuildIndexesIfDirty();
    return _filesMerged;
  }

  List<DriveFile> get mediaFiles {
    _rebuildIndexesIfDirty();
    return _mediaFilesMerged;
  }

  List<DriveFolder> get folders => state.folders;

  Future<void> refresh({bool silent = false, bool force = false}) =>
      _refreshDrive(silent: silent, force: force);

  /// Re-fetches a single folder's page without disturbing other folders. Used
  /// after mutations that affect a known folder, and after upload settle (G3).
  Future<void> refreshFolder(String? folderId, {bool silent = true}) =>
      ensureFolderLoaded(folderId, force: true, silent: silent);

  /// Loads (or refreshes) one folder's page. Race-safe via [_folderLoadGen].
  Future<void> ensureFolderLoaded(
    String? folderId, {
    bool force = false,
    bool silent = false,
  }) => _ensureFolderLoaded(folderId, force: force, silent: silent);

  Future<void> loadMoreFolder(String? folderId) => _loadMoreFolder(folderId);

  void applyDriveState(DriveSnapshot snapshot, {bool notify = true}) =>
      _applyDriveState(snapshot, notify: notify);

  Future<void> loadMoreMedia() => _loadMoreMedia();

  // Starred cache (3h) ------------------------------------------------------

  Future<void> ensureStarredLoaded({bool force = false}) =>
      _ensureStarredLoaded(force: force);

  Future<void> loadMoreStarred() => _loadMoreStarred();

  DriveFile? file(String id) => _file(id);

  DriveFile? anyFile(String id) => _anyFile(id);

  Future<DriveFile?> ensureFileLoaded(String id) => _ensureFileLoaded(id);

  DriveFolder? folder(String id) => _folder(id);

  DriveFolderViewSnapshot folderViewSnapshot(String? folderId) =>
      _folderViewSnapshot(folderId);

  DriveStarredSnapshot starredSnapshot() => _starredSnapshot();

  DriveRecentsSnapshot recentsSnapshot() => _recentsSnapshot();

  void markShared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) => _markShared(fileIds: fileIds, folderIds: folderIds);

  void markUnshared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) => _markUnshared(fileIds: fileIds, folderIds: folderIds);

  List<DriveFolder> folderPath(String id) => _folderPath(id);

  List<DriveFile> recentFiles() => _recentFiles();

  List<DriveFile> photoFiles(String filter) => _photoFiles(filter);

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

  Future<void> markAccessed(String id) => _markAccessed(id);

  void _notifyListeners() {
    notifyListeners();
  }

  void syncOptimisticUploads(List<DriveFile> optimistic) =>
      _syncOptimisticUploads(optimistic);

  void _bumpTrashRevision() {
    state = state.copyWith(trashRevision: state.trashRevision + 1);
    notifyListeners();
  }
}
