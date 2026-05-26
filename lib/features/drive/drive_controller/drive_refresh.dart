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
    bool authoritative = false,
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
      } else if (authoritative) {
        if (existingFile.isOptimistic &&
            existingFile.uploadStatus != 'failed' &&
            existingFile.uploadStatus != 'cancelled') {
          result.add(existingFile);
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
    _recent = await _prefs.recentAccess(userId: _auth.activeAccount?.userId);
    _notifyListeners();
  }

  /// Scope-limited refresh (G3). Refetches the bootstrap (which seeds the
  /// root page) and, if the active folder isn't root, re-fetches that folder
  /// in parallel. Other loaded folder pages stay cached and reload fresh on
  /// next visit if marked stale.
  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
      _notifyListeners();
    }
    try {
      final bootstrapFuture = _repo.getDriveState();
      final activeFolderId = state.activeFolderId;
      final activeFolderFuture = activeFolderId == null
          ? Future<void>.value()
          : ensureFolderLoaded(activeFolderId, force: true, silent: true);
      final snapshot = await bootstrapFuture;
      applyDriveState(snapshot, notify: false);
      await activeFolderFuture;
      state = state.copyWith(loading: false, clearError: true);
      _lastRefreshCompletedAt = DateTime.now();
    } catch (err) {
      state = state.copyWith(
        loading: false,
        error: _repo.api.errorMessage(err, 'Failed to load drive.'),
      );
    }
    _notifyListeners();
  }
}
