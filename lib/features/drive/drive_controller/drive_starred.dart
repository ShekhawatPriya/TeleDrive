part of '../drive_controller.dart';

extension _DriveStarred on DriveController {
  Future<void> _ensureStarredLoaded({bool force = false}) async {
    final cache = state.starred;
    if (!force && cache.loaded && !cache.loading) return;
    if (!force && cache.loading) return;

    final gen = ++_starredLoadGen;
    state = state.copyWith(starred: cache.copyWith(loading: true, error: null));
    _notifyListeners();

    try {
      final results = await Future.wait([
        _repo.listStarredFiles(limit: 60),
        _repo.listStarredFolders(limit: 200),
      ]);
      if (_disposed || _starredLoadGen != gen) return;
      final fileResult =
          results[0] as ({List<DriveFile> files, String? nextCursor});
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
      _notifyListeners();
    } catch (err) {
      if (_disposed || _starredLoadGen != gen) return;
      state = state.copyWith(
        starred: state.starred.copyWith(
          loading: false,
          error: _repo.api.errorMessage(err, 'Failed to load starred.'),
        ),
      );
      _notifyListeners();
    }
  }

  Future<void> _loadMoreStarred() async {
    final cache = state.starred;
    if (cache.loadingMore || !cache.hasMore) return;

    final gen = ++_starredLoadGen;
    state = state.copyWith(
      starred: cache.copyWith(loadingMore: true, error: null),
    );
    _notifyListeners();

    try {
      final fileFuture = cache.fileCursor == null
          ? Future.value((files: <DriveFile>[], nextCursor: cache.fileCursor))
          : _repo.listStarredFiles(limit: 60, cursor: cache.fileCursor);
      final folderFuture = cache.folderCursor == null
          ? Future.value((
              folders: <DriveFolder>[],
              nextCursor: cache.folderCursor,
            ))
          : _repo.listStarredFolders(limit: 200, cursor: cache.folderCursor);
      final results = await Future.wait([fileFuture, folderFuture]);
      if (_disposed || _starredLoadGen != gen) return;
      final fileResult =
          results[0] as ({List<DriveFile> files, String? nextCursor});
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
      _notifyListeners();
    } catch (err) {
      if (_disposed || _starredLoadGen != gen) return;
      state = state.copyWith(
        starred: state.starred.copyWith(
          loadingMore: false,
          error: _repo.api.errorMessage(err, 'Failed to load more starred.'),
        ),
      );
      _notifyListeners();
    }
  }
}
