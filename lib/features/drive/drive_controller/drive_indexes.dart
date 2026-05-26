part of '../drive_controller.dart';

extension _DriveIndexes on DriveController {
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

  bool _filesEqual(DriveFile a, DriveFile b) =>
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

  bool _foldersEqual(DriveFolder a, DriveFolder b) =>
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
  List<DriveFile> _preserveFilesIdentity(
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

  List<DriveFolder> _preserveFoldersIdentity(
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
}
