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
    // only if it is loaded — otherwise the destination will fetch fresh on
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
      // The backend rejects cycles via `assert_can_move_folder` — surface
      // the error and roll back optimistic state.
      state = previousState.copyWith(
        error: _repo.api.errorMessage(err, 'Move failed.'),
      );
      _notifyListeners();
    }
  }

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

    // Optimistic removal across all loaded pages.
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      var pageChanged = false;
      var nextFiles = page.files;
      var nextFolders = page.subfolders;
      if (page.files.any((f) => fileIds.contains(f.id))) {
        nextFiles = page.files.where((f) => !fileIds.contains(f.id)).toList();
        pageChanged = true;
      }
      if (page.subfolders.any((f) => folderIds.contains(f.id))) {
        nextFolders = page.subfolders
            .where((f) => !folderIds.contains(f.id))
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
      mediaFiles: state.mediaFiles.where((f) => !fileIds.contains(f.id)).toList(),
      folderPages: pages,
      folders: state.folders.where((f) => !folderIds.contains(f.id)).toList(),
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
      // Restore only the items that actually failed.
      final restorePages = Map<String?, DriveFolderPage>.of(state.folderPages);
      previousState.folderPages.forEach((parent, prevPage) {
        final cur = restorePages[parent] ?? const DriveFolderPage();
        final restoredFiles = [
          ...cur.files,
          ...prevPage.files.where((f) => failedFileIds.contains(f.id)),
        ];
        final restoredFolders = [
          ...cur.subfolders,
          ...prevPage.subfolders.where((f) => failedFolderIds.contains(f.id)),
        ];
        restorePages[parent] = cur.copyWith(
          files: restoredFiles,
          subfolders: restoredFolders,
        );
      });
      final restoredFolderMeta = previousState.folders
          .where((f) => failedFolderIds.contains(f.id))
          .toList();
      state = state.copyWith(
        mediaFiles: [
          ...state.mediaFiles,
          ...previousState.mediaFiles.where(
            (f) => failedFileIds.contains(f.id),
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
    await Future<void>.delayed(
      Duration(milliseconds: failed > 0 ? 1800 : 700),
    );
    state = state.copyWith(clearDeleteProgress: true);
    _notifyListeners();
  }

  Future<void> _toggleStar(String id, {bool folder = false}) async {
    if (folder) {
      await _toggleFolderStar(id);
    } else {
      await _toggleFileStar(id);
    }
  }

  Future<void> _toggleFolderStar(String id) async {
    final current = state.folders.firstWhereOrNull((f) => f.id == id) ??
        state.starred.folders.firstWhereOrNull((f) => f.id == id);
    if (current == null) return;
    final next = !current.starred;
    final previousFolders = state.folders;
    final previousStarred = state.starred;
    final optimistic = current.copyWith(starred: next);
    _mergeFolderMetadata([optimistic]);
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((f) => f.id == id)) {
        pages[parent] = page.copyWith(
          subfolders: page.subfolders
              .map((f) => f.id == id ? optimistic : f)
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
        state.files.firstWhereOrNull((f) => f.id == id) ??
        state.mediaFiles.firstWhereOrNull((f) => f.id == id) ??
        state.starred.files.firstWhereOrNull((f) => f.id == id);
    if (current == null) return;
    final next = !current.starred;
    final previousState = state;
    final optimistic = current.copyWith(starred: next);
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.files.any((f) => f.id == id)) {
        pages[parent] = page.copyWith(
          files: page.files.map((f) => f.id == id ? optimistic : f).toList(),
        );
      }
    });
    state = state.copyWith(
      mediaFiles: state.mediaFiles
          .map((f) => f.id == id ? optimistic : f)
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
        if (page.files.any((f) => f.id == id)) {
          pagesAfter[parent] = page.copyWith(
            files: page.files.map((f) => f.id == id ? updated : f).toList(),
          );
        }
      });
      state = state.copyWith(
        mediaFiles: state.mediaFiles
            .map((f) => f.id == id ? updated : f)
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

  Future<void> _moveToShelf(
    String id, {
    required _ShelfKind kind,
    required bool archive,
  }) async {
    final previousState = state;
    if (archive) {
      // Optimistically remove from active sets / loaded pages.
      _removeFileFromAllPages(id);
      state = state.copyWith(
        mediaFiles: state.mediaFiles.where((f) => f.id != id).toList(),
        clearError: true,
      );
      _refreshFlatAggregates();
      _notifyListeners();
    } else {
      state = state.copyWith(clearError: true);
    }
    try {
      switch ((kind, archive)) {
        case (_ShelfKind.archive, true):
          await _repo.archiveFile(id);
        case (_ShelfKind.archive, false):
          await _repo.unarchiveFile(id);
        case (_ShelfKind.locked, true):
          await _repo.lockFile(id);
        case (_ShelfKind.locked, false):
          await _repo.unlockFile(id);
      }
      _bumpShelfRevision(kind);
      _markActiveAndAncestorsStale();
      await refreshFolder(state.activeFolderId);
    } catch (err) {
      if (archive) {
        state = previousState.copyWith(
          error: _repo.api.errorMessage(
            err,
            kind == _ShelfKind.archive
                ? 'Could not archive file.'
                : 'Could not lock file.',
          ),
        );
        _refreshFlatAggregates();
      } else {
        state = state.copyWith(
          error: _repo.api.errorMessage(
            err,
            kind == _ShelfKind.archive
                ? 'Could not unarchive file.'
                : 'Could not unlock file.',
          ),
        );
      }
      _notifyListeners();
      rethrow;
    }
  }

  void _bumpShelfRevision(_ShelfKind kind) {
    state = switch (kind) {
      _ShelfKind.archive => state.copyWith(
        archiveRevision: state.archiveRevision + 1,
      ),
      _ShelfKind.locked => state.copyWith(
        lockedRevision: state.lockedRevision + 1,
      ),
    };
    _notifyListeners();
  }
}
