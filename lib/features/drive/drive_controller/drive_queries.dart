part of '../drive_controller.dart';

extension _DriveQueries on DriveController {
  DriveFile? _file(String id) {
    _rebuildIndexesIfDirty();
    return _fileById[id] ?? _resolvedFiles[id];
  }

  DriveFile? _anyFile(String id) {
    _rebuildIndexesIfDirty();
    return _fileById[id] ?? _mediaFileById[id] ?? _resolvedFiles[id];
  }

  Future<DriveFile?> _ensureFileLoaded(String id) {
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

  DriveFolder? _folder(String id) {
    _rebuildIndexesIfDirty();
    return _folderById[id];
  }

  DriveFolderViewSnapshot _folderViewSnapshot(String? folderId) {
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

  DriveStarredSnapshot _starredSnapshot() {
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

  DriveRecentsSnapshot _recentsSnapshot() {
    _rebuildIndexesIfDirty();
    final result = <DriveFile>[];
    for (final file in _filesMerged) {
      if (file.lastAccessedAt != null) result.add(file);
    }
    result.sort((a, b) => b.lastAccessedAt!.compareTo(a.lastAccessedAt!));
    if (result.length > 5) result.length = 5;
    return DriveRecentsSnapshot(List<DriveFile>.unmodifiable(result));
  }

  List<DriveFolder> _folderPath(String id) {
    final path = <DriveFolder>[];
    DriveFolder? current = folder(id);
    while (current != null) {
      path.insert(0, current);
      current = current.parentId == null ? null : folder(current.parentId!);
    }
    return path;
  }

  List<DriveFile> _recentFiles() {
    final result = files.where((file) => file.lastAccessedAt != null).toList()
      ..sort((a, b) => b.lastAccessedAt!.compareTo(a.lastAccessedAt!));
    return result.take(5).toList();
  }

  List<DriveFile> _photoFiles(String filter) {
    final list = [...mediaFiles.where(isMediaFile)]
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return switch (filter) {
      'images' => list.where(isImageFile).toList(),
      'videos' => list.where(isVideoFile).toList(),
      'starred' => list.where((file) => file.starred).toList(),
      _ => list,
    };
  }

  Future<void> _markAccessed(String id) async {
    _recent = {..._recent, id: DateTime.now().toIso8601String()};
    await _prefs.setRecentAccess(_recent, userId: _auth.activeAccount?.userId);
    _notifyListeners();
  }
}
