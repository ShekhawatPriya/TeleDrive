part of '../drive_controller.dart';

extension _DriveDeleteMutations on DriveController {
  Future<void> _deleteItems({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
  }) async {
    final total = fileIds.length + folderIds.length;
    if (total == 0) return;
    var completed = 0;
    var failed = 0;
    String? lastError;
    final failedFileIds = <String>{};
    final failedFolderIds = <String>{};
    final previousState = state;

    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      var pageChanged = false;
      var nextFiles = page.files;
      var nextFolders = page.subfolders;
      if (page.files.any((file) => fileIds.contains(file.id))) {
        nextFiles = page.files
            .where((file) => !fileIds.contains(file.id))
            .toList();
        pageChanged = true;
      }
      if (page.subfolders.any((folder) => folderIds.contains(folder.id))) {
        nextFolders = page.subfolders
            .where((folder) => !folderIds.contains(folder.id))
            .toList();
        pageChanged = true;
      }
      if (pageChanged) {
        pages[parent] = page.copyWith(
          files: nextFiles,
          subfolders: nextFolders,
        );
      }
    });
    state = state.copyWith(
      mediaFiles: state.mediaFiles
          .where((file) => !fileIds.contains(file.id))
          .toList(),
      folderPages: pages,
      folders: state.folders
          .where((folder) => !folderIds.contains(folder.id))
          .toList(),
      deleteProgress: (completed: 0, failed: 0, total: total),
      clearError: true,
    );
    _refreshFlatAggregates();
    _notifyListeners();

    for (final id in fileIds) {
      try {
        if (_settings.state.trashEnabled) {
          await _repo.deleteFile(id);
        } else {
          await _repo.purgeFile(id);
        }
      } catch (error, stackTrace) {
        failed++;
        failedFileIds.add(id);
        lastError = _repo.api.errorMessage(error, 'Delete failed.');
        debugPrint('Delete file $id failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        completed++;
        state = state.copyWith(
          deleteProgress: (completed: completed, failed: failed, total: total),
        );
        _notifyListeners();
      }
    }
    for (final id in folderIds) {
      try {
        if (_settings.state.trashEnabled) {
          await _repo.deleteFolder(id);
        } else {
          await _repo.purgeFolder(id);
        }
      } catch (error, stackTrace) {
        failed++;
        failedFolderIds.add(id);
        lastError = _repo.api.errorMessage(error, 'Delete failed.');
        debugPrint('Delete folder $id failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        completed++;
        state = state.copyWith(
          deleteProgress: (completed: completed, failed: failed, total: total),
        );
        _notifyListeners();
      }
    }
    if (failed > 0) {
      final restorePages = Map<String?, DriveFolderPage>.of(state.folderPages);
      previousState.folderPages.forEach((parent, prevPage) {
        final current = restorePages[parent] ?? const DriveFolderPage();
        final restoredFiles = [
          ...current.files,
          ...prevPage.files.where((file) => failedFileIds.contains(file.id)),
        ];
        final restoredFolders = [
          ...current.subfolders,
          ...prevPage.subfolders.where(
            (folder) => failedFolderIds.contains(folder.id),
          ),
        ];
        restorePages[parent] = current.copyWith(
          files: restoredFiles,
          subfolders: restoredFolders,
        );
      });
      final restoredFolderMeta = previousState.folders
          .where((folder) => failedFolderIds.contains(folder.id))
          .toList();
      state = state.copyWith(
        mediaFiles: [
          ...state.mediaFiles,
          ...previousState.mediaFiles.where(
            (file) => failedFileIds.contains(file.id),
          ),
        ],
        folderPages: restorePages,
        folders: [...state.folders, ...restoredFolderMeta],
        error: lastError ?? 'Some items could not be deleted.',
      );
      _refreshFlatAggregates();
      _notifyListeners();
    }
    _markActiveAndAncestorsStale();
    _bumpTrashRevision();
    try {
      await refreshFolder(state.activeFolderId);
    } catch (_) {}
    await Future<void>.delayed(Duration(milliseconds: failed > 0 ? 1800 : 700));
    state = state.copyWith(clearDeleteProgress: true);
    _notifyListeners();
  }
}
