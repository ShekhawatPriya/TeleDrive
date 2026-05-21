part of '../drive_controller.dart';

extension _DriveRefresh on DriveController {
  bool _filesMatch(DriveFile a, DriveFile b) {
    if (a.id == b.id) return true;
    if (a.localId != null && b.localId != null && a.localId == b.localId) {
      return true;
    }
    if (a.id == 'local:${b.localId}') return true;
    if (b.id == 'local:${a.localId}') return true;
    return false;
  }

  List<DriveFile> _reconcileFiles({
    required List<DriveFile> existing,
    required List<DriveFile> incoming,
    bool removeOrphanedOptimistic = false,
  }) {
    final result = <DriveFile>[];
    final processedIncomingIds = <String>{};

    for (final existingFile in existing) {
      DriveFile? match;
      for (final inc in incoming) {
        if (_filesMatch(existingFile, inc)) {
          match = inc;
          break;
        }
      }

      if (match != null) {
        final localId = match.localId ?? existingFile.localId;
        result.add(match.copyWith(localId: localId));
        processedIncomingIds.add(match.id);
        if (localId != null) {
          processedIncomingIds.add('local:$localId');
        }
      } else if (!removeOrphanedOptimistic || !existingFile.isOptimistic) {
        result.add(existingFile);
      }
    }

    for (final inc in incoming) {
      final key1 = inc.id;
      final key2 = inc.localId != null ? 'local:${inc.localId}' : null;
      if (!processedIncomingIds.contains(key1) &&
          (key2 == null || !processedIncomingIds.contains(key2))) {
        if (inc.isOptimistic) {
          result.insert(0, inc);
        } else {
          result.add(inc);
        }
      }
    }

    return result;
  }

  void _clearStaleForFolder(String? folderId) {
    if (folderId == null) {
      _staleFolderIds.clear();
    } else {
      _staleFolderIds.remove(folderId);
      _staleFolderIds.removeAll(_descendantFolderIds(folderId));
    }
  }

  void _markActiveAndAncestorsStale() {
    _staleFolderIds.add(state.activeFolderId);
    if (state.activeFolderId != null) {
      final parents = folderPath(state.activeFolderId!);
      for (final p in parents) {
        _staleFolderIds.add(p.id);
      }
    }
    _staleFolderIds.add(null);
  }

  Future<void> _loadRecent() async {
    _recent = await _prefs.recentAccess();
    _notifyListeners();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
      _notifyListeners();
    }
    try {
      applyDriveState(await _repo.getDriveState(), notify: false);
      state = state.copyWith(loading: false, clearError: true);
      _lastRefreshCompletedAt = DateTime.now();
      _clearStaleForFolder(state.activeFolderId);
    } catch (err) {
      state = state.copyWith(
        loading: false,
        error: _repo.api.errorMessage(err, 'Failed to load drive.'),
      );
    }
    _notifyListeners();
  }
}
