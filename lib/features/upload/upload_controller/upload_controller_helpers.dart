part of '../upload_controller.dart';

extension _UploadControllerHelpers on UploadController {
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
        _bumpItemsVersion();
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

  String? _backupScope() {
    final user = _auth.user;
    final telegramId = user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    if (user == null || telegramId == 0) return null;
    return '${user.userId}_$telegramId';
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
    // Permission may change while the platform lookup is in flight. A device
    // can also report cellular and Wi-Fi together; Wi-Fi satisfies the policy.
    return !_settings.state.uploadOnMobileData &&
        !connectivity.contains(ConnectivityResult.wifi) &&
        !connectivity.contains(ConnectivityResult.ethernet);
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    if (!items.any((i) => i.status == UploadStatus.waitingForWifi)) return;
    final hasWifi =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    if (!hasWifi && !_settings.state.uploadOnMobileData) return;
    _resumeWaitingUploads();
  }

  void _handleSettingsChanged() {
    if (_settings.state.uploadOnMobileData) _resumeWaitingUploads();
  }

  void _resumeWaitingUploads() {
    if (_disposed || !waitingForWifi) return;
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

  void _notifyListeners({bool force = false}) {
    if (_disposed) return;
    if (force) {
      _notifyScheduled = false;
      _emitChange();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_disposed) return;
      _emitChange();
    });
  }
}
