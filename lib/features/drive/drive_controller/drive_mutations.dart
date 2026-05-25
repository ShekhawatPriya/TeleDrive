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
    state = state.copyWith(folders: [placeholder, ...state.folders]);
    _notifyListeners();
    try {
      final created = await _repo.createFolder(name, parentId);
      state = state.copyWith(
        folders: state.folders
            .map((f) => f.id == tempId ? created : f)
            .toList(),
      );
      _notifyListeners();
      return created;
    } catch (err) {
      state = state.copyWith(
        folders: state.folders.where((f) => f.id != tempId).toList(),
      );
      _notifyListeners();
      rethrow;
    }
  }

  Future<void> _renameFolder(String id, String name) async {
    await _repo.renameFolder(id, name);
    state = state.copyWith(
      folders: state.folders
          .map((f) => f.id == id ? f.copyWith(name: name) : f)
          .toList(),
    );
    _notifyListeners();
  }

  Future<void> _moveFile(String fileId, String? targetFolderId) async {
    final previousFiles = state.files;
    final previousMedia = state.mediaFiles;
    state = state.copyWith(
      files: state.files
          .map((f) => f.id == fileId ? f.copyWith(parentId: targetFolderId) : f)
          .toList(),
      mediaFiles: state.mediaFiles
          .map((f) => f.id == fileId ? f.copyWith(parentId: targetFolderId) : f)
          .toList(),
      clearError: true,
    );
    _notifyListeners();
    try {
      final updated = await _repo.moveFile(fileId, targetFolderId);
      state = state.copyWith(
        files: state.files.map((f) => f.id == fileId ? updated : f).toList(),
        mediaFiles: state.mediaFiles
            .map((f) => f.id == fileId ? updated : f)
            .toList(),
      );
    } catch (err) {
      state = state.copyWith(
        files: previousFiles,
        mediaFiles: previousMedia,
        error: _repo.api.errorMessage(err, 'Move failed.'),
      );
    }
    _notifyListeners();
  }

  Future<void> _moveFolder(String folderId, String? targetParentId) async {
    if (folderId == targetParentId) return;
    final folder = this.folder(folderId);
    if (folder == null) return;
    final descendants = _descendantFolderIds(folderId);
    if (targetParentId != null && descendants.contains(targetParentId)) {
      state = state.copyWith(error: 'Cannot move a folder into itself.');
      _notifyListeners();
      return;
    }

    final previous = state.folders;
    state = state.copyWith(
      folders: state.folders
          .map(
            (f) => f.id == folderId ? f.copyWith(parentId: targetParentId) : f,
          )
          .toList(),
      clearError: true,
    );
    _notifyListeners();

    try {
      final updated = await _repo.moveFolder(folderId, targetParentId);
      state = state.copyWith(
        folders: state.folders
            .map((f) => f.id == folderId ? updated : f)
            .toList(),
      );
    } catch (err) {
      state = state.copyWith(
        folders: previous,
        error: _repo.api.errorMessage(err, 'Move failed.'),
      );
    }
    _notifyListeners();
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
    final oldFiles = state.files;
    final oldMedia = state.mediaFiles;
    final oldFolders = state.folders;
    state = state.copyWith(
      files: state.files.where((f) => !fileIds.contains(f.id)).toList(),
      mediaFiles: state.mediaFiles
          .where((f) => !fileIds.contains(f.id))
          .toList(),
      folders: state.folders.where((f) => !folderIds.contains(f.id)).toList(),
      deleteProgress: (completed: 0, failed: 0, total: total),
      clearError: true,
    );
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
      // Restore only the items that actually failed, preserving items the
      // server already deleted so they don't ghost-back into the UI.
      state = state.copyWith(
        files: [
          ...state.files,
          ...oldFiles.where((f) => failedFileIds.contains(f.id)),
        ],
        mediaFiles: [
          ...state.mediaFiles,
          ...oldMedia.where((f) => failedFileIds.contains(f.id)),
        ],
        folders: [
          ...state.folders,
          ...oldFolders.where((f) => failedFolderIds.contains(f.id)),
        ],
        error: lastError ?? 'Some items could not be deleted.',
      );
      _notifyListeners();
    }
    _markActiveAndAncestorsStale();
    _bumpTrashRevision();
    try {
      await refresh(silent: true, force: true);
    } catch (_) {}
    // Briefly let the user see the final pill state, then clear it.
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
    final current = state.folders.where((f) => f.id == id).firstOrNull;
    if (current == null) return;
    final next = !current.starred;
    final previous = state.folders;
    state = state.copyWith(
      folders: state.folders
          .map((f) => f.id == id ? f.copyWith(starred: next) : f)
          .toList(),
      clearError: true,
    );
    _notifyListeners();
    try {
      final updated = await _repo.setFolderStarred(id, next);
      state = state.copyWith(
        folders: state.folders.map((f) => f.id == id ? updated : f).toList(),
      );
    } catch (err) {
      state = state.copyWith(
        folders: previous,
        error: _repo.api.errorMessage(err, 'Could not update star.'),
      );
    }
    _notifyListeners();
  }

  Future<void> _toggleFileStar(String id) async {
    final current =
        state.files.where((f) => f.id == id).firstOrNull ??
        state.mediaFiles.where((f) => f.id == id).firstOrNull;
    if (current == null) return;
    final next = !current.starred;
    final previousFiles = state.files;
    final previousMedia = state.mediaFiles;
    state = state.copyWith(
      files: state.files
          .map((f) => f.id == id ? f.copyWith(starred: next) : f)
          .toList(),
      mediaFiles: state.mediaFiles
          .map((f) => f.id == id ? f.copyWith(starred: next) : f)
          .toList(),
      clearError: true,
    );
    _notifyListeners();
    try {
      final updated = await _repo.setFileStarred(id, next);
      state = state.copyWith(
        files: state.files.map((f) => f.id == id ? updated : f).toList(),
        mediaFiles: state.mediaFiles
            .map((f) => f.id == id ? updated : f)
            .toList(),
      );
    } catch (err) {
      state = state.copyWith(
        files: previousFiles,
        mediaFiles: previousMedia,
        error: _repo.api.errorMessage(err, 'Could not update star.'),
      );
    }
    _notifyListeners();
  }

  Future<void> _moveToShelf(
    String id, {
    required _ShelfKind kind,
    required bool archive,
  }) async {
    final previousFiles = state.files;
    final previousMedia = state.mediaFiles;
    if (archive) {
      // Optimistically remove from the active sets so the home/folder/photos
      // views update immediately.
      state = state.copyWith(
        files: state.files.where((f) => f.id != id).toList(),
        mediaFiles: state.mediaFiles.where((f) => f.id != id).toList(),
        clearError: true,
      );
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
      await refresh(silent: true, force: true);
    } catch (err) {
      if (archive) {
        state = state.copyWith(
          files: previousFiles,
          mediaFiles: previousMedia,
          error: _repo.api.errorMessage(
            err,
            kind == _ShelfKind.archive
                ? 'Could not archive file.'
                : 'Could not lock file.',
          ),
        );
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
