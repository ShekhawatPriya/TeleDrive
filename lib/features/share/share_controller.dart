import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/share_models.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import 'share_repository.dart';

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => ShareRepository(ref.watch(apiClientProvider)),
);

final shareControllerProvider = ChangeNotifierProvider<ShareController>((ref) {
  return ShareController(
    ref.watch(shareRepositoryProvider),
    ref.read(driveControllerProvider),
  );
});

class ShareController extends ChangeNotifier {
  ShareController(this._repo, this._drive);

  final ShareRepository _repo;
  final DriveController _drive;

  List<Share> _shares = const [];
  final Map<String, Share> _details = {};
  bool _loading = false;
  String? _error;
  Future<void>? _refreshing;
  int _generation = 0;
  int _revision = 0;
  bool _disposed = false;

  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  List<Share> get shares => _shares;
  bool get loading => _loading;
  String? get error => _error;

  void resetForAccountSwitch() {
    _generation++;
    _revision++;
    _shares = const [];
    _details.clear();
    _loading = false;
    _error = null;
    _refreshing = null;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final task = _doRefresh(silent: silent);
    _refreshing = task;
    try {
      await task;
    } finally {
      if (identical(_refreshing, task)) _refreshing = null;
    }
  }

  Future<void> _doRefresh({required bool silent}) async {
    final generation = _generation;
    final revision = _revision;
    if (!silent || _shares.isEmpty) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final shares = await _repo.listShares();
      if (!_current(generation) || revision != _revision) return;
      _shares = shares;
      _error = null;
    } catch (err) {
      if (_current(generation))
        _error = 'Could not refresh shared links. Try again.';
    } finally {
      if (_current(generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<Share> createShare({required List<ShareItemRequest> items}) async {
    final generation = _generation;
    final created = await _repo.createShare(items: items);
    if (!_current(generation)) return created;
    _revision++;
    _shares = [created, ..._shares];
    _details[created.id] = created;
    final fileIds = items
        .where((i) => i.type == ShareItemType.file)
        .map((i) => i.id)
        .toSet();
    final folderIds = items
        .where((i) => i.type == ShareItemType.folder)
        .map((i) => i.id)
        .toSet();
    fileIds.addAll(
      created.items.map((item) => item.fileId).whereType<String>(),
    );
    _drive.markShared(fileIds: fileIds, folderIds: folderIds);
    notifyListeners();
    unawaited(refresh(silent: true));
    return created;
  }

  Future<int> revokeForFile(String fileId) async {
    final generation = _generation;
    final affected = _details.values
        .where((share) => share.items.any((item) => item.fileId == fileId))
        .toList();
    final count = await _repo.revokeForFile(fileId);
    if (!_current(generation)) return count;
    _revision++;
    _shares = _shares
        .where((s) => !s.items.any((it) => it.fileId == fileId))
        .toList();
    _drive.markUnshared(fileIds: {fileId});
    notifyListeners();
    await _reconcileAffected(affected, generation);
    if (_current(generation)) unawaited(refresh(silent: true));
    return count;
  }

  Future<int> revokeForFolder(String folderId) async {
    final generation = _generation;
    final affected = _details.values
        .where(
          (share) => share.items.any(
            (item) => item.folderId == folderId && item.parentPublicId == null,
          ),
        )
        .toList();
    final count = await _repo.revokeForFolder(folderId);
    if (!_current(generation)) return count;
    _revision++;
    _shares = _shares
        .where((s) => !s.items.any((it) => it.folderId == folderId))
        .toList();
    _drive.markUnshared(folderIds: {folderId});
    notifyListeners();
    await _reconcileAffected(affected, generation);
    if (_current(generation)) unawaited(refresh(silent: true));
    return count;
  }

  Future<void> revokeShare(String id, {Share? detail}) async {
    final generation = _generation;
    detail ??= _details[id];
    final previous = _shares;
    _revision++;
    _shares = previous.where((s) => s.id != id).toList();
    notifyListeners();
    try {
      await _repo.revokeShare(id);
      if (!_current(generation)) return;
      _details.remove(id);
      if (detail != null) {
        await _drive.reconcileSharedItems(
          fileIds: detail.items
              .map((item) => item.fileId)
              .whereType<String>()
              .toSet(),
          folderIds: detail.items
              .map((item) => item.folderId)
              .whereType<String>()
              .toSet(),
        );
      }
    } catch (err) {
      if (!_current(generation)) rethrow;
      _revision++;
      // Restore only this item; preserve other concurrent revocations.
      final removed = previous.where((share) => share.id == id);
      if (!_shares.any((share) => share.id == id))
        _shares = [..._shares, ...removed];
      _error = 'Could not revoke this link. Try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _reconcileAffected(List<Share> shares, int generation) async {
    if (!_current(generation) || shares.isEmpty) return;
    for (final share in shares) {
      _details.remove(share.id);
    }
    await _drive.reconcileSharedItems(
      fileIds: shares
          .expand((share) => share.items)
          .map((item) => item.fileId)
          .whereType<String>()
          .toSet(),
      folderIds: shares
          .expand((share) => share.items)
          .where((item) => item.parentPublicId == null)
          .map((item) => item.folderId)
          .whereType<String>()
          .toSet(),
    );
  }

  Future<Share> getShare(String id) async {
    final generation = _generation;
    final share = await _repo.getShare(id);
    if (_current(generation)) _details[id] = share;
    return share;
  }

  Future<({List<ShareAccess> accesses, String? nextCursor})> listAccesses(
    String shareId, {
    bool includeBots = false,
    int limit = 50,
    String? cursor,
  }) {
    return _repo.listAccesses(
      shareId,
      includeBots: includeBots,
      limit: limit,
      cursor: cursor,
    );
  }

  Future<ShareStats> getStats(String shareId, {int days = 30}) {
    return _repo.getStats(shareId, days: days);
  }
}
