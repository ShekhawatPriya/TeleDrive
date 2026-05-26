part of '../drive_controller.dart';

extension _DriveShelfMutations on DriveController {
  Future<void> _moveToShelf(
    String id, {
    required _ShelfKind kind,
    required bool archive,
  }) async {
    final previousState = state;
    if (archive) {
      _removeFileFromAllPages(id);
      state = state.copyWith(
        mediaFiles: state.mediaFiles.where((file) => file.id != id).toList(),
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
