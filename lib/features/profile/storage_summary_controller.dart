import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';

/// Server-truth snapshot of the user's account storage. Sourced from
/// `GET /storage/summary`, which runs a single conditional aggregate over the
/// user's files. The frontend must never sum `drive.files` for storage UI —
/// after on-demand folder loading that list is intentionally partial.
@immutable
class StorageSummary {
  const StorageSummary({
    required this.totalFiles,
    required this.totalBytes,
    required this.imageBytes,
    required this.videoBytes,
    required this.audioBytes,
    required this.documentBytes,
    required this.otherBytes,
    required this.imageCount,
    required this.videoCount,
    required this.audioCount,
    required this.documentCount,
    required this.otherCount,
    required this.trashCount,
    required this.activeUploadCount,
    required this.failedUploadCount,
  });

  final int totalFiles;
  final int totalBytes;
  final int imageBytes;
  final int videoBytes;
  final int audioBytes;
  final int documentBytes;
  final int otherBytes;
  final int imageCount;
  final int videoCount;
  final int audioCount;
  final int documentCount;
  final int otherCount;
  final int trashCount;
  final int activeUploadCount;
  final int failedUploadCount;

  static const empty = StorageSummary(
    totalFiles: 0,
    totalBytes: 0,
    imageBytes: 0,
    videoBytes: 0,
    audioBytes: 0,
    documentBytes: 0,
    otherBytes: 0,
    imageCount: 0,
    videoCount: 0,
    audioCount: 0,
    documentCount: 0,
    otherCount: 0,
    trashCount: 0,
    activeUploadCount: 0,
    failedUploadCount: 0,
  );

  factory StorageSummary.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return StorageSummary(
      totalFiles: read('totalFiles'),
      totalBytes: read('totalBytes'),
      imageBytes: read('imageBytes'),
      videoBytes: read('videoBytes'),
      audioBytes: read('audioBytes'),
      documentBytes: read('documentBytes'),
      otherBytes: read('otherBytes'),
      imageCount: read('imageCount'),
      videoCount: read('videoCount'),
      audioCount: read('audioCount'),
      documentCount: read('documentCount'),
      otherCount: read('otherCount'),
      trashCount: read('trashCount'),
      activeUploadCount: read('activeUploadCount'),
      failedUploadCount: read('failedUploadCount'),
    );
  }
}

class StorageSummaryRepository {
  StorageSummaryRepository(this.api);
  final ApiClient api;

  Future<StorageSummary> fetch() async {
    final res = await api.dio.get('/storage/summary');
    return StorageSummary.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}

final storageSummaryRepositoryProvider = Provider<StorageSummaryRepository>(
  (ref) => StorageSummaryRepository(ref.watch(apiClientProvider)),
);

/// Cached storage summary that auto-refreshes on Drive mutations that can
/// change totals (trash/archive/locked moves) and on demand. Initial fetch
/// is triggered by `ensureLoaded()` from the first storage UI to render.
class StorageSummaryController extends ChangeNotifier {
  StorageSummaryController(this._repo, this._ref) {
    // Refresh once on any revision bump from the Drive controller. These are
    // the cheapest signals we already emit for trash/archive/lock mutations.
    _ref.listen<DriveController>(driveControllerProvider, (prev, next) {
      if (prev == null) return;
      if (prev.state.trashRevision != next.state.trashRevision ||
          prev.state.archiveRevision != next.state.archiveRevision ||
          prev.state.lockedRevision != next.state.lockedRevision) {
        ensureLoaded(force: true);
      }
    });
  }

  final StorageSummaryRepository _repo;
  final Ref _ref;
  StorageSummary? value;
  bool loading = false;
  String? error;
  Future<void>? _inFlight;

  Future<void> ensureLoaded({bool force = false}) {
    if (!force && value != null && !loading) return Future.value();
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final task = _fetch();
    _inFlight = task;
    return task.whenComplete(() {
      if (identical(_inFlight, task)) _inFlight = null;
    });
  }

  Future<void> _fetch() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      value = await _repo.fetch();
    } catch (err) {
      error = 'Failed to load storage usage.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void resetForAccountSwitch() {
    value = null;
    loading = false;
    error = null;
    _inFlight = null;
    notifyListeners();
  }
}

final storageSummaryControllerProvider =
    ChangeNotifierProvider<StorageSummaryController>((ref) {
      return StorageSummaryController(
        ref.watch(storageSummaryRepositoryProvider),
        ref,
      );
    });
