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
  bool _loading = false;
  String? _error;
  Future<void>? _refreshing;

  List<Share> get shares => _shares;
  bool get loading => _loading;
  String? get error => _error;

  void resetForAccountSwitch() {
    _shares = const [];
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
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _shares = await _repo.listShares();
      _error = null;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Share> createShare({required List<ShareItemRequest> items}) async {
    final created = await _repo.createShare(items: items);
    _shares = [created, ..._shares];
    final fileIds = items
        .where((i) => i.type == ShareItemType.file)
        .map((i) => i.id)
        .toSet();
    final folderIds = items
        .where((i) => i.type == ShareItemType.folder)
        .map((i) => i.id)
        .toSet();
    _drive.markShared(fileIds: fileIds, folderIds: folderIds);
    notifyListeners();
    refresh(silent: true);
    return created;
  }

  Future<int> revokeForFile(String fileId) async {
    final count = await _repo.revokeForFile(fileId);
    _shares = _shares
        .where((s) => !s.items.any((it) => it.fileId == fileId))
        .toList();
    _drive.markUnshared(fileIds: {fileId});
    notifyListeners();
    return count;
  }

  Future<int> revokeForFolder(String folderId) async {
    final count = await _repo.revokeForFolder(folderId);
    _shares = _shares
        .where((s) => !s.items.any((it) => it.folderId == folderId))
        .toList();
    _drive.markUnshared(folderIds: {folderId});
    notifyListeners();
    return count;
  }

  Future<void> revokeShare(String id) async {
    final previous = _shares;
    _shares = previous.where((s) => s.id != id).toList();
    notifyListeners();
    try {
      await _repo.revokeShare(id);
    } catch (err) {
      _shares = previous;
      _error = err.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Share> getShare(String id) {
    return _repo.getShare(id);
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
