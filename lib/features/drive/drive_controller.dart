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
    required this.loaded,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
  });

  final String? folderId;
  final DriveFolder? folder;
  final List<DriveFolder> folders;
  final List<DriveFile> files;
  final List<DriveFolder> path;
  final bool loaded;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveFolderViewSnapshot) return false;
    if (other.folderId != folderId) return false;
    if (other.folder != folder) return false;
    if (other.loaded != loaded) return false;
    if (other.loading != loading) return false;
    if (other.loadingMore != loadingMore) return false;
    if (other.hasMore != hasMore) return false;
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
    loaded,
    loading,
    loadingMore,
    hasMore,
    error,
    path.length,
  );
}

class DriveStarredSnapshot {
  const DriveStarredSnapshot({
    required this.files,
    required this.folders,
    required this.loaded,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
  });

  final List<DriveFile> files;
  final List<DriveFolder> folders;
  final bool loaded;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveStarredSnapshot) return false;
    if (other.loaded != loaded ||
        other.loading != loading ||
        other.loadingMore != loadingMore ||
        other.hasMore != hasMore ||
        other.error != error) {
      return false;
    }
    return identical(other.files, files) && identical(other.folders, folders);
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(files),
    identityHashCode(folders),
    loaded,
    loading,
    loadingMore,
    hasMore,
    error,
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

  void _rebuildIndexesIfDirty() {
    final filesDirty = !identical(_lastFilesRef, state.files);
    final mediaDirty = !identical(_lastMediaRef, state.mediaFiles);
    final foldersDirty = !identical(_lastFoldersRef, state.folders);
    final recentDirty = !identical(_lastRecentRef, _recent);
    if (!filesDirty && !mediaDirty && !foldersDirty && !recentDirty) return;
    if (filesDirty || recentDirty) {
      final fileById = <String, DriveFile>{};
      final merged = <DriveFile>[];
      for (final f in state.files) {
        final mergedFile = _recent.containsKey(f.id)
            ? f.copyWith(lastAccessedAt: _recent[f.id])
            : f;
        merged.add(mergedFile);
        fileById[mergedFile.id] = mergedFile;
      }
      _filesMerged = merged;
      _fileById = fileById;
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
      for (final f in state.folders) {
        folderById[f.id] = f;
      }
      _folderById = folderById;
    }
    _lastFilesRef = state.files;
    _lastMediaRef = state.mediaFiles;
    _lastFoldersRef = state.folders;
    _lastRecentRef = _recent;
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

  /// Compares two file lists element-wise for value equality. When equal we
  /// reuse the previous list reference so [DriveFolderViewSnapshot.==] (which
  /// keys on identity) skips unnecessary rebuilds (G2).
  static List<DriveFile> _preserveFilesIdentity(
    List<DriveFile>? previous,
    List<DriveFile> next,
  ) {
    if (previous == null) return next;
    if (identical(previous, next)) return previous;
    if (previous.length != next.length) return next;
    for (var i = 0; i < next.length; i++) {
      if (!_filesEqual(previous[i], next[i])) return next;
    }
    return previous;
  }

  static List<DriveFolder> _preserveFoldersIdentity(
    List<DriveFolder>? previous,
    List<DriveFolder> next,
  ) {
    if (previous == null) return next;
    if (identical(previous, next)) return previous;
    if (previous.length != next.length) return next;
    for (var i = 0; i < next.length; i++) {
      if (!_foldersEqual(previous[i], next[i])) return next;
    }
    return previous;
  }

  /// Stores [page] for [folderId], reusing previous list references when the
  /// underlying contents are unchanged (G2).
  void _applyFolderPage(String? folderId, DriveFolderPage page) {
    final previous = state.folderPages[folderId];
    final preservedFiles = _preserveFilesIdentity(previous?.files, page.files);
    final preservedSubfolders = _preserveFoldersIdentity(
      previous?.subfolders,
      page.subfolders,
    );
    final next = page.copyWith(
      files: preservedFiles,
      subfolders: preservedSubfolders,
    );
    final updatedPages = Map<String?, DriveFolderPage>.of(state.folderPages);
    updatedPages[folderId] = next;
    state = state.copyWith(folderPages: updatedPages);
    _refreshFlatAggregates();
    _mergeFolderMetadata(page.subfolders);
  }

  /// Merges folder metadata into the global `_folderById` and `state.folders`
  /// list. Folder metadata is small and cumulative — we keep it complete
  /// across navigation so breadcrumbs always resolve.
  void _mergeFolderMetadata(Iterable<DriveFolder> folders) {
    if (folders.isEmpty) return;
    final byId = {for (final f in state.folders) f.id: f};
    var changed = false;
    for (final f in folders) {
      final prev = byId[f.id];
      if (prev == null || !_foldersEqual(prev, f)) {
        byId[f.id] = f;
        changed = true;
      }
    }
    if (!changed) return;
    state = state.copyWith(folders: byId.values.toList());
  }

  /// Rebuilds the flat `state.files` / `state.mediaFiles` aggregates from the
  /// union of every loaded folder page plus media, preserving optimistic
  /// entries already present. Upload-compat (G1) reads `state.files`, so this
  /// must remain stable.
  void _refreshFlatAggregates() {
    final flat = <String, DriveFile>{};
    for (final f in state.files.where((f) => f.isOptimistic)) {
      flat[f.id] = f;
    }
    for (final page in state.folderPages.values) {
      for (final f in page.files) {
        flat[f.id] = f;
      }
    }
    final flatList = flat.values.toList();
    state = state.copyWith(files: flatList);
  }

  void setActiveFolderId(String? folderId) {
    if (state.activeFolderId == folderId) {
      // Even when unchanged, ensure the page is loaded (e.g. tab re-entry).
      _maybeEnsureFolderLoaded(folderId);
      return;
    }
    state = state.copyWith(activeFolderId: folderId);
    _notifyListeners();
    _maybeEnsureFolderLoaded(folderId);
  }

  void _maybeEnsureFolderLoaded(String? folderId) {
    final page = state.folderPages[folderId];
    final stale = _staleFolderIds.contains(folderId);
    if (page == null || !page.loaded || stale) {
      ensureFolderLoaded(folderId, force: stale);
    }
  }

  Future<void> resetForAccountSwitch() async {
    state = const DriveState(loading: true);
    _recent = {};
    _refreshing = null;
    _lastRefreshCompletedAt = null;
    _staleFolderIds.clear();
    _resolvedFiles.clear();
    _fileFetches.clear();
    // Bump every gen so any in-flight folder fetch is discarded on return.
    for (final key in _folderLoadGen.keys.toList()) {
      _folderLoadGen[key] = (_folderLoadGen[key] ?? 0) + 1;
    }
    _starredLoadGen += 1;
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

  /// Re-fetches a single folder's page without disturbing other folders. Used
  /// after mutations that affect a known folder, and after upload settle (G3).
  Future<void> refreshFolder(String? folderId, {bool silent = true}) {
    return ensureFolderLoaded(folderId, force: true, silent: silent);
  }

  /// Loads (or refreshes) one folder's page. Race-safe via [_folderLoadGen].
  Future<void> ensureFolderLoaded(
    String? folderId, {
    bool force = false,
    bool silent = false,
  }) async {
    final page = state.folderPages[folderId];
    final stale = _staleFolderIds.contains(folderId);
    if (!force && page != null && page.loaded && !stale) return;
    if (!force && page != null && page.loading) return;

    final gen = (_folderLoadGen[folderId] ?? 0) + 1;
    _folderLoadGen[folderId] = gen;

    final basePage = page ?? const DriveFolderPage();
    if (!silent || !basePage.loaded) {
      _applyFolderPage(
        folderId,
        basePage.copyWith(loading: true, error: null),
      );
      _notifyListeners();
    }

    try {
      final results = await Future.wait([
        _repo.listFiles(folderId: folderId, limit: 60),
        _repo.listFolderChildren(parentId: folderId, limit: 200),
      ]);
      if (_folderLoadGen[folderId] != gen) return;
      final fileResult =
          results[0] as ({List<DriveFile> files, String? nextCursor});
      final folderResult = results[1]
          as ({
            List<DriveFolder> folders,
            String? nextCursor,
            List<DriveFolder> path,
          });

      // Merge any path folders so breadcrumbs render even on deep links (G4).
      _mergeFolderMetadata(folderResult.path);

      // Preserve optimistic items already in this page.
      final optimistic = (page?.files ?? const <DriveFile>[])
          .where((f) => f.isOptimistic)
          .toList();
      final mergedFiles = <DriveFile>[
        ...optimistic,
        ...fileResult.files.where(
          (f) => !optimistic.any((o) => o.id == f.id || o.localId == f.localId),
        ),
      ];

      _staleFolderIds.remove(folderId);
      _applyFolderPage(
        folderId,
        DriveFolderPage(
          files: mergedFiles,
          subfolders: folderResult.folders,
          fileCursor: fileResult.nextCursor,
          folderCursor: folderResult.nextCursor,
          loaded: true,
          loading: false,
          loadingMore: false,
          error: null,
        ),
      );
      _lastRefreshCompletedAt = DateTime.now();
      _notifyListeners();
    } catch (err) {
      if (_folderLoadGen[folderId] != gen) return;
      final current = state.folderPages[folderId] ?? const DriveFolderPage();
      _applyFolderPage(
        folderId,
        current.copyWith(
          loading: false,
          error: _repo.api.errorMessage(err, 'Failed to load folder.'),
        ),
      );
      _notifyListeners();
    }
  }

  Future<void> loadMoreFolder(String? folderId) async {
    final page = state.folderPages[folderId];
    if (page == null || page.loadingMore) return;
    if (!page.hasMore) return;

    final gen = (_folderLoadGen[folderId] ?? 0) + 1;
    _folderLoadGen[folderId] = gen;
    _applyFolderPage(folderId, page.copyWith(loadingMore: true, error: null));
    _notifyListeners();

    try {
      final fileFuture = page.fileCursor == null
          ? Future.value((files: <DriveFile>[], nextCursor: page.fileCursor))
          : _repo.listFiles(
              folderId: folderId,
              limit: 60,
              cursor: page.fileCursor,
            );
      final folderFuture = page.folderCursor == null
          ? Future.value(
              (
                folders: <DriveFolder>[],
                nextCursor: page.folderCursor,
                path: <DriveFolder>[],
              ),
            )
          : _repo.listFolderChildren(
              parentId: folderId,
              limit: 200,
              cursor: page.folderCursor,
            );
      final results = await Future.wait([fileFuture, folderFuture]);
      if (_folderLoadGen[folderId] != gen) return;
      final fileResult =
          results[0] as ({List<DriveFile> files, String? nextCursor});
      final folderResult = results[1]
          as ({
            List<DriveFolder> folders,
            String? nextCursor,
            List<DriveFolder> path,
          });

      final existingFileIds = page.files.map((f) => f.id).toSet();
      final existingFolderIds = page.subfolders.map((f) => f.id).toSet();
      final mergedFiles = <DriveFile>[
        ...page.files,
        ...fileResult.files.where((f) => !existingFileIds.contains(f.id)),
      ];
      final mergedFolders = <DriveFolder>[
        ...page.subfolders,
        ...folderResult.folders.where(
          (f) => !existingFolderIds.contains(f.id),
        ),
      ];

      _applyFolderPage(
        folderId,
        page.copyWith(
          files: mergedFiles,
          subfolders: mergedFolders,
          fileCursor: page.fileCursor == null
              ? page.fileCursor
              : fileResult.nextCursor,
          folderCursor: page.folderCursor == null
              ? page.folderCursor
              : folderResult.nextCursor,
          loadingMore: false,
        ),
      );
      _notifyListeners();
    } catch (err) {
      if (_folderLoadGen[folderId] != gen) return;
      final current = state.folderPages[folderId] ?? const DriveFolderPage();
      _applyFolderPage(
        folderId,
        current.copyWith(
          loadingMore: false,
          error: _repo.api.errorMessage(err, 'Failed to load more.'),
        ),
      );
      _notifyListeners();
    }
  }

  void applyDriveState(DriveSnapshot snapshot, {bool notify = true}) {
    final incomingMedia = snapshot.mediaFiles
        .where((f) => f.uploadStatus == 'available')
        .toList();
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: incomingMedia,
      authoritative: true,
    );

    // Seed root page with the bootstrap's direct root files + folders.
    final rootRowsFiles = snapshot.files
        .where((f) => f.uploadStatus == 'available')
        .toList();
    final rootOptimistic = (state.folderPages[null]?.files ?? const <DriveFile>[])
        .where((f) => f.isOptimistic && f.parentId == null)
        .toList();
    final rootFiles = <DriveFile>[
      ...rootOptimistic,
      ...rootRowsFiles.where((f) => !rootOptimistic.any((o) => o.id == f.id)),
    ];

    // Merge folder metadata first so subsequent page identity preservation
    // sees the latest folder records.
    final keptOptimisticFolders = state.folders
        .where((f) => f.isOptimistic)
        .toList();
    _mergeFolderMetadata([...keptOptimisticFolders, ...snapshot.folders]);

    final rootPage = DriveFolderPage(
      files: rootFiles,
      subfolders: snapshot.folders,
      fileCursor: snapshot.rootFileCursor,
      folderCursor: snapshot.rootFolderCursor,
      loaded: true,
      loading: false,
      loadingMore: false,
      error: null,
    );
    _applyFolderPage(null, rootPage);
    _staleFolderIds.remove(null);

    state = state.copyWith(
      mediaFiles: updatedMedia,
      mediaCursor: snapshot.mediaCursor,
      loading: false,
      clearError: true,
    );
    _refreshFlatAggregates();
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

  // Starred cache (3h) ------------------------------------------------------

  Future<void> ensureStarredLoaded({bool force = false}) async {
    final cache = state.starred;
    if (!force && cache.loaded && !cache.loading) return;
    if (!force && cache.loading) return;

    final gen = ++_starredLoadGen;
    state = state.copyWith(
      starred: cache.copyWith(loading: true, error: null),
    );
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.listStarredFiles(limit: 60),
        _repo.listStarredFolders(limit: 200),
      ]);
      if (_starredLoadGen != gen) return;
      final fileResult = results[0] as ({List<DriveFile> files, String? nextCursor});
      final folderResult =
          results[1] as ({List<DriveFolder> folders, String? nextCursor});
      _mergeFolderMetadata(folderResult.folders);
      state = state.copyWith(
        starred: DriveStarredCache(
          files: fileResult.files,
          folders: folderResult.folders,
          fileCursor: fileResult.nextCursor,
          folderCursor: folderResult.nextCursor,
          loaded: true,
          loading: false,
          loadingMore: false,
          error: null,
        ),
      );
      notifyListeners();
    } catch (err) {
      if (_starredLoadGen != gen) return;
      state = state.copyWith(
        starred: state.starred.copyWith(
          loading: false,
          error: _repo.api.errorMessage(err, 'Failed to load starred.'),
        ),
      );
      notifyListeners();
    }
  }

  Future<void> loadMoreStarred() async {
    final cache = state.starred;
    if (cache.loadingMore || !cache.hasMore) return;

    final gen = ++_starredLoadGen;
    state = state.copyWith(
      starred: cache.copyWith(loadingMore: true, error: null),
    );
    notifyListeners();

    try {
      final fileFuture = cache.fileCursor == null
          ? Future.value((files: <DriveFile>[], nextCursor: cache.fileCursor))
          : _repo.listStarredFiles(limit: 60, cursor: cache.fileCursor);
      final folderFuture = cache.folderCursor == null
          ? Future.value(
              (folders: <DriveFolder>[], nextCursor: cache.folderCursor),
            )
          : _repo.listStarredFolders(limit: 200, cursor: cache.folderCursor);
      final results = await Future.wait([fileFuture, folderFuture]);
      if (_starredLoadGen != gen) return;
      final fileResult = results[0] as ({List<DriveFile> files, String? nextCursor});
      final folderResult =
          results[1] as ({List<DriveFolder> folders, String? nextCursor});

      final existingFileIds = cache.files.map((f) => f.id).toSet();
      final existingFolderIds = cache.folders.map((f) => f.id).toSet();
      _mergeFolderMetadata(folderResult.folders);
      state = state.copyWith(
        starred: cache.copyWith(
          files: [
            ...cache.files,
            ...fileResult.files.where((f) => !existingFileIds.contains(f.id)),
          ],
          folders: [
            ...cache.folders,
            ...folderResult.folders.where(
              (f) => !existingFolderIds.contains(f.id),
            ),
          ],
          fileCursor: cache.fileCursor == null
              ? cache.fileCursor
              : fileResult.nextCursor,
          folderCursor: cache.folderCursor == null
              ? cache.folderCursor
              : folderResult.nextCursor,
          loadingMore: false,
        ),
      );
      notifyListeners();
    } catch (err) {
      if (_starredLoadGen != gen) return;
      state = state.copyWith(
        starred: state.starred.copyWith(
          loadingMore: false,
          error: _repo.api.errorMessage(err, 'Failed to load more starred.'),
        ),
      );
      notifyListeners();
    }
  }

  void _patchStarredFile(DriveFile file, {required bool starred}) {
    final cache = state.starred;
    if (!cache.loaded) return;
    if (starred) {
      if (cache.files.any((f) => f.id == file.id)) return;
      state = state.copyWith(
        starred: cache.copyWith(files: [file, ...cache.files]),
      );
    } else {
      final next = cache.files.where((f) => f.id != file.id).toList();
      if (next.length == cache.files.length) return;
      state = state.copyWith(starred: cache.copyWith(files: next));
    }
  }

  void _patchStarredFolder(DriveFolder folder, {required bool starred}) {
    final cache = state.starred;
    if (!cache.loaded) return;
    if (starred) {
      if (cache.folders.any((f) => f.id == folder.id)) return;
      state = state.copyWith(
        starred: cache.copyWith(folders: [folder, ...cache.folders]),
      );
    } else {
      final next = cache.folders.where((f) => f.id != folder.id).toList();
      if (next.length == cache.folders.length) return;
      state = state.copyWith(starred: cache.copyWith(folders: next));
    }
  }

  // Folder page helpers -----------------------------------------------------

  void _insertOptimisticFolder(String? parentId, DriveFolder folder) {
    final page = state.folderPages[parentId] ?? const DriveFolderPage();
    final next = [folder, ...page.subfolders];
    _applyFolderPage(parentId, page.copyWith(subfolders: next));
    _mergeFolderMetadata([folder]);
  }

  void _replaceFolderEverywhere(String oldId, DriveFolder replacement) {
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((f) => f.id == oldId)) {
        final next = page.subfolders
            .map((f) => f.id == oldId ? replacement : f)
            .toList();
        pages[parent] = page.copyWith(subfolders: next);
      }
    });
    state = state.copyWith(folderPages: pages);
    _mergeFolderMetadata([replacement]);
  }

  void _removeFolderEverywhere(String folderId) {
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((f) => f.id == folderId)) {
        pages[parent] = page.copyWith(
          subfolders: page.subfolders.where((f) => f.id != folderId).toList(),
        );
      }
    });
    state = state.copyWith(folderPages: pages);
    final byId = {for (final f in state.folders) f.id: f};
    if (byId.remove(folderId) != null) {
      state = state.copyWith(folders: byId.values.toList());
    }
  }

  void _removeFileFromAllPages(String fileId) {
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    var changed = false;
    pages.forEach((parent, page) {
      if (page.files.any((f) => f.id == fileId)) {
        pages[parent] = page.copyWith(
          files: page.files.where((f) => f.id != fileId).toList(),
        );
        changed = true;
      }
    });
    if (changed) {
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }
  }

  // Snapshots & lookups -----------------------------------------------------

  DriveFile? file(String id) {
    _rebuildIndexesIfDirty();
    return _fileById[id] ?? _resolvedFiles[id];
  }

  DriveFile? anyFile(String id) {
    _rebuildIndexesIfDirty();
    return _fileById[id] ?? _mediaFileById[id] ?? _resolvedFiles[id];
  }

  /// Resolves a file by id with a server fallback (`GET /files/{id}`). The
  /// route layer often only has the id (search results, starred, deep links),
  /// and after on-demand loading `_fileById` is intentionally partial.
  ///
  /// Returns the cached row immediately when available, otherwise fetches
  /// once and merges the result into the loose `_resolvedFiles` cache (and
  /// into the matching folder page if that page is already loaded — never
  /// triggers a folder fetch on its behalf). Concurrent calls for the same
  /// id share one in-flight future.
  Future<DriveFile?> ensureFileLoaded(String id) {
    final cached = anyFile(id);
    if (cached != null && !cached.isOptimistic) {
      return Future.value(cached);
    }
    final inFlight = _fileFetches[id];
    if (inFlight != null) return inFlight;
    final task = _fetchFile(id);
    _fileFetches[id] = task;
    return task.whenComplete(() => _fileFetches.remove(id));
  }

  Future<DriveFile?> _fetchFile(String id) async {
    try {
      final fetched = await _repo.getFile(id);
      _resolvedFiles[id] = fetched;
      // If the file's parent folder is already loaded, splice it into that
      // page so other consumers (folder view, etc.) see it.
      final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
      final parentId = fetched.parentId;
      final page = pages[parentId];
      if (page != null && page.loaded && !page.files.any((f) => f.id == id)) {
        pages[parentId] = page.copyWith(files: [...page.files, fetched]);
        state = state.copyWith(folderPages: pages);
        _refreshFlatAggregates();
      }
      notifyListeners();
      return fetched;
    } catch (_) {
      return null;
    }
  }

  DriveFolder? folder(String id) {
    _rebuildIndexesIfDirty();
    return _folderById[id];
  }

  DriveFolderViewSnapshot folderViewSnapshot(String? folderId) {
    _rebuildIndexesIfDirty();
    final folderMeta = folderId == null ? null : _folderById[folderId];
    final page = state.folderPages[folderId];
    final files = page?.files ?? const <DriveFile>[];
    final folders = page?.subfolders ?? const <DriveFolder>[];
    final loaded = page?.loaded ?? false;
    final loading = page?.loading ?? false;
    final loadingMore = page?.loadingMore ?? false;
    final hasMore = page?.hasMore ?? false;
    final path = folderId == null
        ? const <DriveFolder>[]
        : folderPath(folderId);
    return DriveFolderViewSnapshot(
      folderId: folderId,
      folder: folderMeta,
      folders: folders,
      files: files,
      path: path,
      loaded: loaded,
      loading: loading,
      loadingMore: loadingMore,
      hasMore: hasMore,
      error: page?.error ?? state.error,
    );
  }

  DriveStarredSnapshot starredSnapshot() {
    final cache = state.starred;
    return DriveStarredSnapshot(
      files: cache.files,
      folders: cache.folders,
      loaded: cache.loaded,
      loading: cache.loading,
      loadingMore: cache.loadingMore,
      hasMore: cache.hasMore,
      error: cache.error,
    );
  }

  /// Recent files **among the currently loaded Drive cache**.
  ///
  /// `markAccessed()` records access timestamps in `_recent` (id → ISO date,
  /// persisted to prefs and survives cold start), but Recents can only
  /// display a file we have a full row for. After on-demand loading, that's
  /// the union of every loaded folder page + media files + optimistic
  /// uploads — *not* a global list. A recently-accessed file that lives in
  /// an unvisited folder is intentionally absent until that folder is
  /// loaded; the timestamp is preserved and surfaces as soon as the folder
  /// is opened. The `DriveRecentsStrip` caller hides itself on empty result,
  /// so cold-start renders cleanly with no strip rather than a broken one.
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
    if (fileIds.isNotEmpty) {
      final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
      pages.forEach((parent, page) {
        if (page.files.any((f) => fileIds.contains(f.id))) {
          pages[parent] = page.copyWith(
            files: page.files
                .map(
                  (f) => fileIds.contains(f.id) ? f.copyWith(shared: true) : f,
                )
                .toList(),
          );
        }
      });
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }
    if (folderIds.isNotEmpty) {
      final byId = {for (final f in state.folders) f.id: f};
      for (final id in folderIds) {
        final f = byId[id];
        if (f != null) byId[id] = f.copyWith(shared: true);
      }
      state = state.copyWith(folders: byId.values.toList());
    }
    notifyListeners();
  }

  void markUnshared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    if (fileIds.isNotEmpty) {
      final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
      pages.forEach((parent, page) {
        if (page.files.any((f) => fileIds.contains(f.id))) {
          pages[parent] = page.copyWith(
            files: page.files
                .map(
                  (f) => fileIds.contains(f.id) ? f.copyWith(shared: false) : f,
                )
                .toList(),
          );
        }
      });
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }
    if (folderIds.isNotEmpty) {
      final byId = {for (final f in state.folders) f.id: f};
      for (final id in folderIds) {
        final f = byId[id];
        if (f != null) byId[id] = f.copyWith(shared: false);
      }
      state = state.copyWith(folders: byId.values.toList());
    }
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

  /// See [recentsSnapshot] — same loaded-cache-only contract, different
  /// shape (plain list, no immutable wrapper). Used by call sites that don't
  /// need the snapshot's identity-preserving equality.
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

  /// Upload-compat surface (G1). Reconciles optimistic uploads into the
  /// relevant folder pages and the media list. Patches per-parent so an
  /// upload tick into folder X does not rebuild folder Y's snapshot (G2).
  void syncOptimisticUploads(List<DriveFile> optimistic) {
    final keep = optimistic
        .where((f) => f.uploadStatus != 'cancelled')
        .toList();

    // Group optimistic items by parent. Items missing from a particular page
    // (because they completed against the server snapshot) are removed via
    // [_reconcileFiles] with `removeOrphanedOptimistic: true`.
    final byParent = <String?, List<DriveFile>>{};
    for (final f in keep) {
      (byParent[f.parentId] ??= <DriveFile>[]).add(f);
    }

    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    final touchedParents = <String?>{...pages.keys, ...byParent.keys};
    var anyChanged = false;
    for (final parent in touchedParents) {
      final page = pages[parent];
      final incomingForParent = byParent[parent] ?? const <DriveFile>[];
      final existing = page?.files ?? const <DriveFile>[];
      final reconciled = _reconcileFiles(
        existing: existing,
        incoming: incomingForParent,
        removeOrphanedOptimistic: true,
      );
      final preserved = _preserveFilesIdentity(existing, reconciled);
      if (identical(preserved, existing)) continue;
      pages[parent] = (page ?? const DriveFolderPage())
          .copyWith(files: preserved);
      anyChanged = true;
      // If the upload landed in a folder we haven't loaded yet, mark stale so
      // a subsequent visit fetches the real server-truth (G3).
      if (page == null || !page.loaded) {
        _staleFolderIds.add(parent);
      }
    }
    if (anyChanged) {
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }

    final keepMedia = keep.where(isMediaFile).toList();
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: keepMedia,
      removeOrphanedOptimistic: true,
    );
    final mediaUnchanged =
        _filesFingerprint(updatedMedia) == _filesFingerprint(state.mediaFiles);

    if (!mediaUnchanged) {
      state = state.copyWith(mediaFiles: updatedMedia);
    }
    if (anyChanged || !mediaUnchanged) {
      notifyListeners();
    }
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
}
