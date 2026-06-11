part of '../drive_controller.dart';

extension _DriveStateBootstrap on DriveController {
  void _applyDriveState(DriveSnapshot snapshot, {bool notify = true}) {
    final incomingMedia = snapshot.mediaFiles
        .where((f) => f.uploadStatus == 'available')
        .toList();
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: incomingMedia,
      authoritative: true,
    );

    final rootRowsFiles = snapshot.files
        .where((f) => f.uploadStatus == 'available')
        .toList();
    // Server rows are authoritative: matched optimistic upload copies are
    // promoted, unmatched in-flight optimistic items survive.
    final rootFiles = _reconcileFiles(
      existing: state.folderPages[null]?.files ?? const <DriveFile>[],
      incoming: rootRowsFiles,
      authoritative: true,
    );

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
    if (notify) _notifyListeners();
  }

  Future<void> _loadMoreMedia() async {
    if (state.mediaCursor == null || state.loadingMoreMedia) return;
    state = state.copyWith(loadingMoreMedia: true);
    _notifyListeners();
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
    _notifyListeners();
  }
}
