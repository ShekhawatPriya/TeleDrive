part of '../drive_controller.dart';

extension _DriveRefresh on DriveController {
  /// True for rows that came from the server and are fully settled — these
  /// are authoritative and must never be replaced by an optimistic upload
  /// copy (which the upload sheet keeps emitting until thumbnails are ready).
  bool _isSettledServerFile(DriveFile file) =>
      !file.isOptimistic &&
      (file.uploadStatus == null || file.uploadStatus == 'available');

  /// Server row replaces a matched optimistic upload copy, but keeps the
  /// local media paths so the tile can keep rendering the on-device preview
  /// until the server has a renderable thumbnail/preview of its own.
  DriveFile _promoteServerFile(
    DriveFile optimistic,
    DriveFile server, {
    String? localId,
  }) {
    var promoted = server.copyWith(localId: localId);
    if (server.localUri == null && optimistic.localUri != null) {
      promoted = promoted.copyWith(localUri: optimistic.localUri);
    }
    final hasServerMedia =
        server.thumbnailUrl != null ||
        server.previewUrl != null ||
        server.thumbnailRefAvailable ||
        server.previewRefAvailable;
    if (!hasServerMedia) {
      promoted = promoted.copyWith(
        thumbnailUrl: optimistic.thumbnailUrl,
        previewUrl: optimistic.previewUrl,
      );
    }
    return promoted;
  }

  List<DriveFile> _reconcileFiles({
    required List<DriveFile> existing,
    required List<DriveFile> incoming,
    bool removeOrphanedOptimistic = false,
    bool authoritative = false,
  }) {
    final result = <DriveFile>[];
    final processedIncomingIds = <String>{};

    // Index both server and local identities once. Preserve the first incoming
    // match when aliases overlap, matching the original reconciliation contract.
    final byIdentity = <String, int>{};
    for (var index = 0; index < incoming.length; index++) {
      final file = incoming[index];
      byIdentity.putIfAbsent(file.id, () => index);
      if (file.localId != null)
        byIdentity.putIfAbsent('local:${file.localId}', () => index);
    }
    for (final existingFile in existing) {
      final byId = byIdentity[existingFile.id];
      final byLocal = existingFile.localId == null
          ? null
          : byIdentity['local:${existingFile.localId}'];
      final index = byId == null
          ? byLocal
          : byLocal == null || byId < byLocal
          ? byId
          : byLocal;
      final match = index == null ? null : incoming[index];

      if (match != null) {
        final localId = match.localId ?? existingFile.localId;
        if (match.isOptimistic && _isSettledServerFile(existingFile)) {
          result.add(existingFile.copyWith(localId: localId));
        } else if (existingFile.isOptimistic && !match.isOptimistic) {
          result.add(_promoteServerFile(existingFile, match, localId: localId));
        } else {
          result.add(match.copyWith(localId: localId));
        }
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
    _markFolderAndAncestorsStale(state.activeFolderId);
  }

  /// Marks [folderId], its ancestor chain, and root stale so each refetches
  /// fresh on next visit. Safe when the folder's metadata isn't known yet —
  /// the unloaded page will fetch on navigation regardless.
  void _markFolderAndAncestorsStale(String? folderId) {
    _staleFolderIds.add(folderId);
    if (folderId != null) {
      for (final p in folderPath(folderId)) {
        _staleFolderIds.add(p.id);
      }
    }
    _staleFolderIds.add(null);
  }

  Future<void> _loadRecent() async {
    final generation = _accountGeneration;
    final recent = await _prefs.recentAccess(
      userId: _auth.activeAccount?.userId,
    );
    if (!_isCurrentAccount(generation)) return;
    _recent = recent;
    _notifyListeners();
  }

  /// Scope-limited refresh (G3). Refetches the bootstrap (which seeds the
  /// root page) and, if the active folder isn't root, re-fetches that folder
  /// in parallel. Other loaded folder pages stay cached and reload fresh on
  /// next visit if marked stale.
  Future<void> _refresh({bool silent = false}) async {
    final generation = _accountGeneration;
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
      final results = await Future.wait<Object?>([
        bootstrapFuture,
        activeFolderFuture,
      ]);
      if (!_isCurrentAccount(generation)) return;
      applyDriveState(results.first as DriveSnapshot, notify: false);
      state = state.copyWith(loading: false, clearError: true);
      _lastRefreshCompletedAt = DateTime.now();
    } catch (err) {
      if (!_isCurrentAccount(generation)) return;
      state = state.copyWith(
        loading: false,
        error: _repo.api.errorMessage(err, 'Failed to load drive.'),
      );
    }
    _notifyListeners();
  }
}
