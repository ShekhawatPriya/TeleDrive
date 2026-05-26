part of '../drive_controller.dart';

extension _DriveStarMutations on DriveController {
  Future<void> _toggleStar(String id, {bool folder = false}) async {
    if (folder) {
      await _toggleFolderStar(id);
    } else {
      await _toggleFileStar(id);
    }
  }

  Future<void> _toggleFolderStar(String id) async {
    final current =
        state.folders.firstWhereOrNull((folder) => folder.id == id) ??
        state.starred.folders.firstWhereOrNull((folder) => folder.id == id);
    if (current == null) return;
    final next = !current.starred;
    final previousFolders = state.folders;
    final previousStarred = state.starred;
    final optimistic = current.copyWith(starred: next);
    _mergeFolderMetadata([optimistic]);
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((folder) => folder.id == id)) {
        pages[parent] = page.copyWith(
          subfolders: page.subfolders
              .map((folder) => folder.id == id ? optimistic : folder)
              .toList(),
        );
      }
    });
    state = state.copyWith(folderPages: pages, clearError: true);
    _patchStarredFolder(optimistic, starred: next);
    _notifyListeners();
    try {
      final updated = await _repo.setFolderStarred(id, next);
      _replaceFolderEverywhere(id, updated);
      _patchStarredFolder(updated, starred: next);
      _notifyListeners();
    } catch (err) {
      state = state.copyWith(
        folders: previousFolders,
        starred: previousStarred,
        error: _repo.api.errorMessage(err, 'Could not update star.'),
      );
      _notifyListeners();
    }
  }

  Future<void> _toggleFileStar(String id) async {
    final current =
        state.files.firstWhereOrNull((file) => file.id == id) ??
        state.mediaFiles.firstWhereOrNull((file) => file.id == id) ??
        state.starred.files.firstWhereOrNull((file) => file.id == id);
    if (current == null) return;
    final next = !current.starred;
    final previousState = state;
    final optimistic = current.copyWith(starred: next);
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.files.any((file) => file.id == id)) {
        pages[parent] = page.copyWith(
          files: page.files
              .map((file) => file.id == id ? optimistic : file)
              .toList(),
        );
      }
    });
    state = state.copyWith(
      mediaFiles: state.mediaFiles
          .map((file) => file.id == id ? optimistic : file)
          .toList(),
      folderPages: pages,
      clearError: true,
    );
    _refreshFlatAggregates();
    _patchStarredFile(optimistic, starred: next);
    _notifyListeners();
    try {
      final updated = await _repo.setFileStarred(id, next);
      final pagesAfter = Map<String?, DriveFolderPage>.of(state.folderPages);
      pagesAfter.forEach((parent, page) {
        if (page.files.any((file) => file.id == id)) {
          pagesAfter[parent] = page.copyWith(
            files: page.files
                .map((file) => file.id == id ? updated : file)
                .toList(),
          );
        }
      });
      state = state.copyWith(
        mediaFiles: state.mediaFiles
            .map((file) => file.id == id ? updated : file)
            .toList(),
        folderPages: pagesAfter,
      );
      _refreshFlatAggregates();
      _patchStarredFile(updated, starred: next);
      _notifyListeners();
    } catch (err) {
      state = previousState.copyWith(
        error: _repo.api.errorMessage(err, 'Could not update star.'),
      );
      _refreshFlatAggregates();
      _notifyListeners();
    }
  }
}
