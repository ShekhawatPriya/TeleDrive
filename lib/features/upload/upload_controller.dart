import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/upload_notification_service.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/media/client_derivative_generator.dart';
import '../../core/telegram/pending_telegram_commit_queue.dart';
import '../../core/telegram/telegram_client_exceptions.dart';
import '../../core/telegram/telegram_client_models.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import '../../core/utils/iterable_ext.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import '../profile/app_settings_controller.dart';
import '../profile/gallery_backup_asset_store.dart';
import 'upload_models.dart';
import 'upload_picker_helper.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';

part 'upload_controller/upload_state_sync.dart';
part 'upload_controller/upload_transport.dart';

final uploadControllerProvider = ChangeNotifierProvider<UploadController>((
  ref,
) {
  return UploadController(
    ref.read(apiClientProvider),
    ref.read(driveControllerProvider),
    ref.read(appSettingsControllerProvider),
    ref.read(uploadNotificationServiceProvider),
    ref.read(authControllerProvider),
    ref.read(telegramTransferServiceProvider),
  );
});

class UploadController extends ChangeNotifier {
  UploadController(
    this._api,
    this._drive,
    this._settings,
    this._notifications,
    this._auth,
    this._telegram,
  ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  static const maxFiles = 50;
  static const pollInterval = Duration(milliseconds: 1200);

  final ApiClient _api;
  final DriveController _drive;
  final AppSettingsController _settings;
  final UploadNotificationService _notifications;
  final AuthController _auth;
  final TelegramTransferService _telegram;
  final ClientDerivativeGenerator _derivatives =
      const ClientDerivativeGenerator();
  final PendingTelegramCommitQueue _pendingCommits =
      PendingTelegramCommitQueue();
  final GalleryBackupAssetStore _backupAssetStore =
      const GalleryBackupAssetStore();
  final _uuid = const Uuid();
  final Map<String, CancelToken> _cancelTokensByLocalId = {};
  final Map<int, Timer> _pollTimersByBatchId = {};
  final Set<int> _pollingBatchIds = {};
  final Set<String> _runningLocalIds = {};
  final Map<int, DateTime> _batchUploadFinishedTimes = {};
  Timer? _autoDismissTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _refreshedUploadSessionId;
  String? _notifiedSessionId;
  bool _disposed = false;

  String? uploadSessionId;
  List<UploadItem> items = [];
  bool picking = false;
  bool uploading = false;
  bool sheetVisible = false;
  String? activeFolderId;
  String? error;

  int get uploadedCount =>
      items.where((i) => i.status == UploadStatus.uploaded).length;
  int get failedCount => items
      .where(
        (i) =>
            i.status == UploadStatus.failed ||
            i.status == UploadStatus.cancelled,
      )
      .length;
  int get activeCount => items.where(_isActive).length;
  bool get waitingForWifi =>
      items.any((i) => i.status == UploadStatus.waitingForWifi);
  Set<String> get activeGalleryBackupFingerprints => items
      .where(
        (i) =>
            i.clientSource == 'gallery_backup' &&
            i.backupFingerprint != null &&
            !_isTerminalStatus(i.status),
      )
      .map((i) => i.backupFingerprint!)
      .toSet();
  int get activeGalleryBackupQueueCount =>
      activeGalleryBackupFingerprints.length;
  bool get hasBlockingUploads =>
      uploading ||
      activeCount > 0 ||
      items.any(
        (i) => {
          UploadStatus.queued,
          UploadStatus.waitingForWifi,
          UploadStatus.preparingMetadata,
          UploadStatus.creatingThumbnail,
          UploadStatus.creatingPreview,
          UploadStatus.uploadingOriginalToTelegram,
          UploadStatus.uploadingThumbnailToTelegram,
          UploadStatus.uploadingPreviewToTelegram,
          UploadStatus.committingMetadata,
          UploadStatus.processing,
          UploadStatus.cancelling,
        }.contains(i.status),
      );

  Future<void> pickFiles({String? folderId, BuildContext? context}) async {
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickFiles(maxFiles: maxFiles),
      'Document picking failed.',
      context: context,
    );
  }

  Future<void> pickPhoto({String? folderId, BuildContext? context}) async {
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickPhoto(),
      'Camera capture failed.',
      context: context,
    );
  }

  Future<void> _handlePicker(
    Future<UploadPickerResult> Function() pickAction,
    String defaultErrorMessage, {
    BuildContext? context,
  }) async {
    if (picking || uploading) return;
    picking = true;
    error = null;
    _notifyListeners();
    try {
      final res = await pickAction();
      if (res.error != null) {
        error = res.error;
        sheetVisible = true;
      } else if (res.items != null) {
        uploadSessionId = res.sessionId;
        items = res.items!;
        sheetVisible = items.isNotEmpty;
        _syncOptimistic();
        // The picker completes before this optional UI confirmation; callers
        // pass a still-mounted context from the current screen.
        // ignore: use_build_context_synchronously
        final shouldUpload = await _confirmLargeUploadsIfNeeded(context);
        if (!shouldUpload) {
          dismiss();
          return;
        }
        await confirmUpload();
      }
    } catch (err) {
      error = _api.errorMessage(err, defaultErrorMessage);
      sheetVisible = true;
    } finally {
      picking = false;
      _notifyListeners();
    }
  }

  Future<void> confirmUpload() async {
    final retryable = {
      UploadStatus.selected,
      UploadStatus.failed,
      UploadStatus.cancelled,
      UploadStatus.waitingForWifi,
    };
    if (!items.any((i) => retryable.contains(i.status))) return;
    _cancelCompletionTimers();
    uploadSessionId ??= _uuid.v4();
    uploading = true;
    error = null;
    items = items
        .map(
          (i) => retryable.contains(i.status)
              ? i.copyWith(
                  uploadClientId: _uuid.v4(),
                  status: UploadStatus.queued,
                  httpProgress: 0,
                  serverProgress: 0,
                  clearError: true,
                  cancelRequested: false,
                  resetServerIds: true,
                  clearThumbnail: true,
                )
              : i,
        )
        .toList();
    _syncOptimistic();
    _notifyListeners();
    _pumpQueue();
  }

  Future<void> enqueueGalleryBackupItems(List<UploadItem> backupItems) async {
    if (backupItems.isEmpty) return;
    _cancelCompletionTimers();
    uploadSessionId ??= _uuid.v4();
    uploading = true;
    error = null;
    sheetVisible = true;
    items = [
      ...items,
      ...backupItems.map(
        (item) => item.copyWith(
          uploadClientId: _uuid.v4(),
          status: UploadStatus.queued,
          httpProgress: 0,
          serverProgress: 0,
          clearError: true,
          cancelRequested: false,
          resetServerIds: true,
          clearThumbnail: true,
          clientSource: 'gallery_backup',
        ),
      ),
    ];
    _syncOptimistic();
    _notifyListeners();
    _pumpQueue();
  }

  Future<void> pauseQueuedGalleryBackupItems() async {
    final scope = _backupScope();
    final paused = items
        .where(
          (item) =>
              item.clientSource == 'gallery_backup' &&
              {
                UploadStatus.selected,
                UploadStatus.queued,
                UploadStatus.waitingForWifi,
              }.contains(item.status),
        )
        .toList();
    if (paused.isEmpty) return;
    for (final item in paused) {
      if (item.deleteLocalOnComplete) {
        unawaited(_safeDeleteLocalFile(item.path));
      }
    }
    if (scope != null) {
      await _backupAssetStore.markMany(
        scope,
        paused
            .map((item) => item.backupFingerprint)
            .whereType<String>()
            .where((value) => value.isNotEmpty),
        GalleryBackupAssetStatus.discovered,
      );
    }
    items = items
        .where(
          (item) => !paused.any((paused) => paused.localId == item.localId),
        )
        .toList();
    _syncOptimistic();
    _updateUploadingFlag();
    _notifyListeners();
  }

  Future<void> cancelItem(String localId) async {
    final item = _findItem(localId);
    if (item == null || _isTerminalStatus(item.status)) return;
    _setItem(localId, status: UploadStatus.cancelling, cancelRequested: true);
    _cancelTokensByLocalId[localId]?.cancel('Upload cancelled.');
    unawaited(_telegram.cancelTransfer(item.uploadClientId));

    if (item.batchId != null) {
      final endpoint = item.uploadJobId == null
          ? '/upload-batches/${item.batchId}/cancel'
          : '/upload-jobs/${item.uploadJobId}/cancel';
      await _api.dio
          .post(endpoint)
          .catchError((_) => Response(requestOptions: RequestOptions()));
    }

    if (item.batchId != null) _stopPollingBatch(item.batchId!);
    _runningLocalIds.remove(localId);
    _setItem(localId, status: UploadStatus.cancelled);
    if (item.deleteLocalOnComplete) {
      unawaited(_safeDeleteLocalFile(item.path));
    }
    _syncOptimistic();
    _pumpQueue();
  }

  String? _backupScope() {
    final user = _auth.user;
    final telegramId = user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    if (user == null || telegramId == 0) return null;
    return '${user.userId}_$telegramId';
  }

  Future<void> cancelUpload() async {
    final activeIds = items
        .where((i) => _isActive(i) || i.status == UploadStatus.selected)
        .map((i) => i.localId)
        .toList();
    for (final id in activeIds) {
      await cancelItem(id);
    }
    await _refreshDrive();
  }

  Future<void> retryFailed() async {
    items = items
        .map(
          (i) =>
              i.status == UploadStatus.failed ||
                  i.status == UploadStatus.cancelled
              ? i.copyWith(
                  status: UploadStatus.selected,
                  httpProgress: 0,
                  serverProgress: 0,
                  clearError: true,
                  cancelRequested: false,
                  resetServerIds: true,
                  clearThumbnail: true,
                )
              : i,
        )
        .toList();
    _notifyListeners();
    await confirmUpload();
  }

  void removeFailed(String localId) {
    final item = _findItem(localId);
    if (item == null) return;
    if (item.status != UploadStatus.failed &&
        item.status != UploadStatus.cancelled) {
      return;
    }
    if (item.deleteLocalOnComplete) {
      unawaited(_safeDeleteLocalFile(item.path));
    }
    items = items.where((i) => i.localId != localId).toList();
    if (items.isEmpty) {
      sheetVisible = false;
      uploadSessionId = null;
      error = null;
    }
    _syncOptimistic();
    _notifyListeners();
  }

  void dismiss() {
    if (uploading) return;
    for (final timer in _pollTimersByBatchId.values) {
      timer.cancel();
    }
    _pollTimersByBatchId.clear();
    for (final item in items) {
      if (item.deleteLocalOnComplete) {
        _safeDeleteLocalFile(item.path);
      }
    }
    items = [];
    sheetVisible = false;
    uploadSessionId = null;
    error = null;
    _syncOptimistic();
    _notifyListeners();
  }

  void resetTerminalForAccountSwitch() {
    if (hasBlockingUploads) return;
    for (final timer in _pollTimersByBatchId.values) {
      timer.cancel();
    }
    _pollTimersByBatchId.clear();
    _pollingBatchIds.clear();
    _cancelCompletionTimers();
    items = [];
    sheetVisible = false;
    uploadSessionId = null;
    activeFolderId = null;
    error = null;
    uploading = false;
    _syncOptimistic();
    _notifyListeners();
  }

  Future<void> enableMobileDataUploads() async {
    await _settings.setUploadOnMobileData(true);
    items = items
        .map(
          (i) => i.status == UploadStatus.waitingForWifi
              ? i.copyWith(status: UploadStatus.queued)
              : i,
        )
        .toList();
    _notifyListeners();
    _pumpQueue();
  }

  Future<bool> _confirmLargeUploadsIfNeeded(BuildContext? context) async {
    if (!_settings.state.askBeforeLargeUploads || context == null) return true;
    final threshold = _auth.largeUploadThresholdBytes;
    final large = items.where((i) => i.size > threshold).toList();
    if (large.isEmpty) return true;
    final totalBytes = large.fold<int>(0, (sum, item) => sum + item.size);
    final thresholdMbStr =
        '${(threshold / (1024 * 1024)).toStringAsFixed(0)} MB';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          large.length == 1 ? 'Upload large file?' : 'Upload large files?',
        ),
        content: Text(
          large.length == 1
              ? '"${large.first.name}" is larger than $thresholdMbStr. It may take time, use mobile or Wi-Fi data, and consume upload resources.'
              : '${large.length} selected files are larger than $thresholdMbStr (${formatFileSize(totalBytes)} total). They may take time, use data, and consume upload resources.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue upload'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _isBlockedOnMobileData() async {
    if (_settings.state.uploadOnMobileData) return false;
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.contains(ConnectivityResult.mobile);
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    if (!items.any((i) => i.status == UploadStatus.waitingForWifi)) return;
    final hasWifi =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    if (!hasWifi) return;
    items = items
        .map(
          (i) => i.status == UploadStatus.waitingForWifi
              ? i.copyWith(status: UploadStatus.queued)
              : i,
        )
        .toList();
    _notifyListeners();
    _pumpQueue();
  }

  Future<void> _notifyUploadSettledIfNeeded() async {
    final sessionId = uploadSessionId;
    if (sessionId == null || _notifiedSessionId == sessionId || items.isEmpty) {
      return;
    }
    final settled = items.every(
      (i) =>
          i.status == UploadStatus.uploaded ||
          i.status == UploadStatus.failed ||
          i.status == UploadStatus.cancelled,
    );
    if (!settled) return;
    _notifiedSessionId = sessionId;
    final failed = failedCount;
    if (failed > 0 && _settings.state.uploadFailedAlerts) {
      await _notifications.showUploadFailed(failed: failed);
    } else if (failed == 0 && _settings.state.uploadCompletedAlerts) {
      await _notifications.showUploadComplete(total: items.length, failed: 0);
    }
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _pollTimersByBatchId.values) {
      timer.cancel();
    }
    _connectivitySubscription?.cancel();
    _cancelCompletionTimers();
    _pollingBatchIds.clear();
    for (final token in _cancelTokensByLocalId.values) {
      token.cancel();
    }
    super.dispose();
  }
}
