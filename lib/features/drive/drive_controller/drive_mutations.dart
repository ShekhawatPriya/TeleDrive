part of '../drive_controller.dart';

enum _ShelfKind { archive, locked }

extension _DriveMutations on DriveController {
  Future<DriveFolder> _createFolder(String name, String? parentId) async {
    final tempId = 'local:${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    final placeholder = DriveFolder(
      id: tempId,
      name: name,
      parentId: parentId,
      modifiedAt: now,
      createdAt: now,
      isOptimistic: true,
    );
    _insertOptimisticFolder(parentId, placeholder);
    _notifyListeners();
    try {
      final created = await _repo.createFolder(name, parentId);
      _replaceFolderEverywhere(tempId, created);
      _notifyListeners();
      return created;
    } catch (err) {
      _removeFolderEverywhere(tempId);
      _notifyListeners();
      rethrow;
    }
  }

  Future<void> _renameFolder(String id, String name) async {
    await _repo.renameFolder(id, name);
    final byId = {for (final f in state.folders) f.id: f};
    final existing = byId[id];
    if (existing != null) {
      _mergeFolderMetadata([existing.copyWith(name: name)]);
    }
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((f) => f.id == id)) {
        pages[parent] = page.copyWith(
          subfolders: page.subfolders
              .map((f) => f.id == id ? f.copyWith(name: name) : f)
              .toList(),
        );
      }
    });
    state = state.copyWith(folderPages: pages);
    _notifyListeners();
  }

  Future<void> _moveFile(String fileId, String? targetFolderId) async {
    final previousState = state;
    final source = state.files.firstWhereOrNull((f) => f.id == fileId);
    if (source == null) return;

    final movedFile = source.copyWith(parentId: targetFolderId);

    // Optimistically remove from source page; insert into destination page
    // only if it is loaded â€” otherwise the destination will fetch fresh on
    // next visit (G3 / 3i).
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    final sourcePage = pages[source.parentId];
    if (sourcePage != null) {
      pages[source.parentId] = sourcePage.copyWith(
        files: sourcePage.files.where((f) => f.id != fileId).toList(),
      );
    }
    final destPage = pages[targetFolderId];
    if (destPage != null) {
      pages[targetFolderId] = destPage.copyWith(
        files: [movedFile, ...destPage.files.where((f) => f.id != fileId)],
      );
    } else {
      _staleFolderIds.add(targetFolderId);
    }
    state = state.copyWith(
      mediaFiles: state.mediaFiles
          .map((f) => f.id == fileId ? movedFile : f)
          .toList(),
      folderPages: pages,
      clearError: true,
    );
    _refreshFlatAggregates();
    _notifyListeners();

    try {
      final updated = await _repo.moveFile(fileId, targetFolderId);
      // Patch with the server-truth row in the destination page (if loaded)
      // and in mediaFiles.
      final pagesAfter = Map<String?, DriveFolderPage>.of(state.folderPages);
      final destAfter = pagesAfter[targetFolderId];
      if (destAfter != null) {
        pagesAfter[targetFolderId] = destAfter.copyWith(
          files: destAfter.files
              .map((f) => f.id == fileId ? updated : f)
              .toList(),
        );
        state = state.copyWith(folderPages: pagesAfter);
      }
      state = state.copyWith(
        mediaFiles: state.mediaFiles
            .map((f) => f.id == fileId ? updated : f)
            .toList(),
      );
      _refreshFlatAggregates();
    } catch (err) {
      state = previousState.copyWith(
        error: _repo.api.errorMessage(err, 'Move failed.'),
      );
      _refreshFlatAggregates();
    }
    _notifyListeners();
  }

  Future<void> _moveFolder(String folderId, String? targetParentId) async {
    if (folderId == targetParentId) return;
    final folder = this.folder(folderId);
    if (folder == null) return;

    final previousState = state;
    final movedFolder = folder.copyWith(parentId: targetParentId);

    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    final sourcePage = pages[folder.parentId];
    if (sourcePage != null) {
      pages[folder.parentId] = sourcePage.copyWith(
        subfolders: sourcePage.subfolders
            .where((f) => f.id != folderId)
            .toList(),
      );
    }
    final destPage = pages[targetParentId];
    if (destPage != null) {
      pages[targetParentId] = destPage.copyWith(
        subfolders: [
          movedFolder,
          ...destPage.subfolders.where((f) => f.id != folderId),
        ],
      );
    } else {
      _staleFolderIds.add(targetParentId);
    }
    state = state.copyWith(folderPages: pages, clearError: true);
    _mergeFolderMetadata([movedFolder]);
    _notifyListeners();

    try {
      final updated = await _repo.moveFolder(folderId, targetParentId);
      _replaceFolderEverywhere(folderId, updated);
      _notifyListeners();
    } catch (err) {
      // The backend rejects cycles via `assert_can_move_folder` â€” surface
      // the error and roll back optimistic state.
      state = previousState.copyWith(
        error: _repo.api.errorMessage(err, 'Move failed.'),
      );
      _notifyListeners();
    }
  }
}
