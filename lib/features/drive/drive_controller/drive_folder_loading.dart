part of '../drive_controller.dart';

extension _DriveFolderLoading on DriveController {
  void _setActiveFolderId(String? folderId) {
    if (state.activeFolderId == folderId) {
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
      _ensureFolderLoaded(
        folderId,
        force: stale,
        silent: page != null && page.loaded,
      );
    }
  }

  Future<void> _resetForAccountSwitch() async {
    state = const DriveState(loading: true);
    _recent = {};
    _refreshing = null;
    _lastRefreshCompletedAt = null;
    _staleFolderIds.clear();
    _resolvedFiles.clear();
    _fileFetches.clear();
    for (final key in _folderLoadGen.keys.toList()) {
      _folderLoadGen[key] = (_folderLoadGen[key] ?? 0) + 1;
    }
    _starredLoadGen += 1;
    _notifyListeners();
    await _loadRecent();
  }

  Future<void> _refreshDrive({bool silent = false, bool force = false}) async {
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

  Future<void> _ensureFolderLoaded(
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
      _applyFolderPage(folderId, basePage.copyWith(loading: true, error: null));
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
      final folderResult =
          results[1]
              as ({
                List<DriveFolder> folders,
                String? nextCursor,
                List<DriveFolder> path,
              });

      _mergeFolderMetadata(folderResult.path);

      // Server rows are authoritative: matched optimistic upload copies get
      // promoted to their server counterparts; unmatched in-flight optimistic
      // items survive so upload tiles don't vanish mid-flight.
      final mergedFiles = _reconcileFiles(
        existing: page?.files ?? const <DriveFile>[],
        incoming: fileResult.files,
        authoritative: true,
      );

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

  Future<void> _loadMoreFolder(String? folderId) async {
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
          ? Future.value((
              folders: <DriveFolder>[],
              nextCursor: page.folderCursor,
              path: <DriveFolder>[],
            ))
          : _repo.listFolderChildren(
              parentId: folderId,
              limit: 200,
              cursor: page.folderCursor,
            );
      final results = await Future.wait([fileFuture, folderFuture]);
      if (_folderLoadGen[folderId] != gen) return;
      final fileResult =
          results[0] as ({List<DriveFile> files, String? nextCursor});
      final folderResult =
          results[1]
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
        ...folderResult.folders.where((f) => !existingFolderIds.contains(f.id)),
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
}
