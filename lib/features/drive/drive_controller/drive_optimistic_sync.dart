part of '../drive_controller.dart';

extension _DriveOptimisticSync on DriveController {
  void _syncOptimisticUploads(List<DriveFile> optimistic) {
    final keep = optimistic
        .where((file) => file.uploadStatus != 'cancelled')
        .toList();

    final byParent = <String?, List<DriveFile>>{};
    for (final file in keep) {
      (byParent[file.parentId] ??= <DriveFile>[]).add(file);
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
      // If an uploaded optimistic row was stripped before its server
      // counterpart landed in this page, the page is missing real content —
      // make sure the next visit refetches it.
      final removedUploaded = existing.any(
        (f) =>
            f.isOptimistic &&
            f.uploadStatus == 'uploaded' &&
            !f.id.startsWith('local:') &&
            !reconciled.any((r) => r.id == f.id),
      );
      if (removedUploaded) {
        _staleFolderIds.add(parent);
      }
      final preserved = _preserveFilesIdentity(existing, reconciled);
      if (identical(preserved, existing)) continue;
      pages[parent] = (page ?? const DriveFolderPage()).copyWith(
        files: preserved,
      );
      anyChanged = true;
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
      _notifyListeners();
    }
  }

  int _filesFingerprint(List<DriveFile> files) {
    if (files.isEmpty) return 0;
    var hash = 0;
    for (final file in files) {
      hash = Object.hash(
        hash,
        file.id,
        file.name,
        file.parentId,
        file.kind,
        file.size,
        file.modifiedAt,
        file.createdAt,
        file.starred,
        file.shared,
        file.mimeType,
        file.uploadStatus,
        file.uploadError,
        Object.hash(
          file.storageMode,
          file.uploadOrigin,
          file.publicProxyStatus,
          file.verificationStatus,
          file.mediaAccessMode,
          file.originalRefAvailable,
          file.thumbnailRefAvailable,
          file.previewRefAvailable,
        ),
        Object.hash(
          file.thumbnailUrl,
          file.previewUrl,
          file.streamUrl,
          file.downloadUrl,
          file.localUri,
          file.thumbnailStatus,
          file.previewStatus,
          file.thumbnailVersion,
          file.previewVersion,
          file.widthPx,
          file.heightPx,
          file.duration,
          file.lastAccessedAt,
          file.isOptimistic,
          file.localId,
        ),
      );
    }
    return hash;
  }
}
