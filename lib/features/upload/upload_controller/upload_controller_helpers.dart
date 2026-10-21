part of '../upload_controller.dart';

extension _UploadControllerHelpers on UploadController {
  Future<void> _handlePicker(
    Future<UploadPickerResult> Function() pickAction,
    String defaultErrorMessage, {
    String? folderId,
    BuildContext? context,
  }) async {
    if (picking) return;
    final owner = (_auth.user?.userId, _auth.user?.telegramId, _auth.token);
    picking = true;
    error = null;
    _notifyListeners();
    try {
      final res = await pickAction();
      if (_disposed ||
          owner != (_auth.user?.userId, _auth.user?.telegramId, _auth.token))
        return;
      if (res.error != null) {
        error = res.error;
        sheetVisible = true;
      } else if (res.items != null && res.items!.isNotEmpty) {
        final picked = _addPickedItems(res.items!, folderId: folderId);
        // The picker completes before this optional UI confirmation; callers
        // pass a still-mounted context from the current screen.
        final shouldUpload = await _confirmLargeUploadsIfNeeded(
          // ignore: use_build_context_synchronously
          context,
          picked,
        );
        if (_disposed ||
            owner != (_auth.user?.userId, _auth.user?.telegramId, _auth.token))
          return;
        final ids = picked.map((i) => i.localId).toSet();
        if (!shouldUpload) {
          _discardSelected(ids);
          return;
        }
        _queueSelected(ids);
      }
    } catch (err) {
      error = _api.errorMessage(err, defaultErrorMessage);
      sheetVisible = true;
    } finally {
      picking = false;
      _notifyListeners();
    }
  }

  /// Adds a pick to the queue. With nothing in flight it starts a fresh
  /// session (clearing settled rows); otherwise the new items join the back of
  /// the running queue. Every item is pinned to its own destination, so a pick
  /// in another folder cannot redirect files that are already queued.
  List<UploadItem> _addPickedItems(
    List<UploadItem> pickedItems, {
    String? folderId,
  }) {
    final picked = [
      for (final item in pickedItems)
        item.copyWith(destinationFolderId: folderId ?? uploadRootFolderId),
    ];
    if (!hasBlockingUploads) {
      for (final item in items) {
        if (item.deleteLocalOnComplete) {
          unawaited(_safeDeleteLocalFile(item.path));
        }
      }
      items = picked;
      uploadSessionId = _uuid.v4();
      activeFolderId = folderId;
    } else {
      items = [
        for (final item in items)
          item.destinationFolderId == null
              ? item.copyWith(
                  destinationFolderId: activeFolderId ?? uploadRootFolderId,
                )
              : item,
        ...picked,
      ];
      // A session that already reported its outcome reports the new files
      // as a new outcome (haptics, alerts, Live Activity).
      if (_notifiedSessionId != null && _notifiedSessionId == uploadSessionId) {
        uploadSessionId = _uuid.v4();
      }
    }
    _cancelCompletionTimers();
    _bumpItemsVersion();
    sheetVisible = true;
    _syncOptimistic();
    _notifyListeners();
    for (final item in picked) {
      if (detectFileKind(item.name, item.mimeType) == FileKind.video) {
        unawaited(_attachPoster(item));
      }
    }
    return picked;
  }

  Future<void> _attachPoster(UploadItem item) async {
    String? poster;
    try {
      poster = await _derivatives.createUploadPoster(
        localId: item.localId,
        videoPath: item.path,
        filename: item.name,
      );
    } catch (_) {
      return;
    }
    if (poster == null) return;
    if (_disposed || _findItem(item.localId) == null) {
      unawaited(_safeDeleteLocalFile(poster));
      return;
    }
    _posterPaths[item.localId] = poster;
    items = [
      for (final current in items)
        current.localId == item.localId
            ? current.copyWith(posterPath: poster)
            : current,
    ];
    _syncOptimistic();
    _notifyListeners();
  }

  /// Drops picked items the person declined before they were queued.
  void _discardSelected(Set<String> localIds) {
    for (final item in items) {
      if (localIds.contains(item.localId) && item.deleteLocalOnComplete) {
        unawaited(_safeDeleteLocalFile(item.path));
      }
    }
    items = items.where((i) => !localIds.contains(i.localId)).toList();
    _bumpItemsVersion();
    if (items.isEmpty) {
      sheetVisible = false;
      uploadSessionId = null;
      error = null;
    }
    _syncOptimistic();
    _updateUploadingFlag();
    _notifyListeners(force: true);
  }

  /// Why Telegram would refuse [item], or null. Before the account tier is
  /// known only files above the Premium ceiling are refused.
  String? _oversizeMessage(UploadItem item) {
    final premium = _telegramPremium;
    final limit = premium == false
        ? UploadController.telegramMaxFileBytes
        : UploadController.telegramPremiumMaxFileBytes;
    if (item.size <= limit) return null;
    return premium == false
        ? 'Telegram accepts files up to 2 GB (4 GB with Telegram Premium). '
              'This file is ${formatFileSize(item.size)}.'
        : 'Telegram accepts files up to 4 GB. This file is '
              '${formatFileSize(item.size)}.';
  }

  Future<void> _failOversized(UploadItem item, String message) async {
    _setItem(
      item.localId,
      status: UploadStatus.failed,
      error: message,
      notify: false,
    );
    final scope = _backupScope();
    if (scope != null && item.backupFingerprint != null) {
      await _backupAssetStore.mark(
        scope,
        item.backupFingerprint!,
        GalleryBackupAssetStatus.failed,
        failureCode: 'telegram_file_too_large',
        failureMessage: message,
      );
    }
  }

  String? _backupScope() {
    final user = _auth.user;
    final telegramId = user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    if (user == null || telegramId == 0) return null;
    return '${user.userId}_$telegramId';
  }

  Future<bool> _confirmLargeUploadsIfNeeded(
    BuildContext? context,
    List<UploadItem> candidates,
  ) async {
    if (!_settings.state.askBeforeLargeUploads ||
        context == null ||
        !context.mounted) {
      return true;
    }
    final threshold = _auth.largeUploadThresholdBytes;
    final large = candidates.where((i) => i.size > threshold).toList();
    if (large.isEmpty) return true;
    final totalBytes = large.fold<int>(0, (sum, item) => sum + item.size);
    final thresholdMbStr =
        '${(threshold / (1024 * 1024)).toStringAsFixed(0)} MB';
    final title = large.length == 1
        ? 'Upload large file?'
        : 'Upload large files?';
    final message = large.length == 1
        ? '"${large.first.name}" is larger than $thresholdMbStr. It may take time, use mobile or Wi-Fi data, and consume upload resources.'
        : '${large.length} selected files are larger than $thresholdMbStr (${formatFileSize(totalBytes)} total). They may take time, use data, and consume upload resources.';
    final result = Theme.of(context).platform == TargetPlatform.iOS
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(
                large.length == 1
                    ? 'Upload Large File?'
                    : 'Upload Large Files?',
              ),
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Upload'),
                ),
              ],
            ),
          )
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(title),
              content: Text(message),
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
    _syncLiveActivity();
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
    if (sessionId == null || items.isEmpty) return;
    final settled = items.every(
      (i) =>
          i.status == UploadStatus.uploaded ||
          i.status == UploadStatus.failed ||
          i.status == UploadStatus.cancelled,
    );
    if (!settled) return;
    // A retried session settles again: its Live Activity still has to end,
    // but haptics and alerts belong to the first outcome only.
    final firstOutcome = _notifiedSessionId != sessionId;
    _notifiedSessionId = sessionId;
    final failed = failedCount;
    // Feedback only for uploads the user started, not background backup.
    if (firstOutcome && items.any((i) => i.backupFingerprint == null)) {
      failed > 0 ? AppHaptics.error() : AppHaptics.success();
    }
    final failedAlert =
        firstOutcome && failed > 0 && _settings.state.uploadFailedAlerts;
    final completedAlert =
        firstOutcome && failed == 0 && _settings.state.uploadCompletedAlerts;
    final snapshot = uploadActivitySnapshot(items);
    // A running Live Activity reports the outcome itself, carrying the alert
    // so the person is not notified twice (HIG).
    final alertDelivered =
        snapshot != null &&
        _liveActivity.isTracking(sessionId) &&
        await _liveActivity.finish(
          sessionId: sessionId,
          snapshot: snapshot,
          foreground: _notifications.isForeground,
          alert: failedAlert || completedAlert
              ? _liveActivityAlert(snapshot)
              : null,
        );
    if (alertDelivered) return;
    if (failedAlert) {
      await _notifications.showUploadFailed(failed: failed);
    } else if (completedAlert) {
      await _notifications.showUploadComplete(total: items.length, failed: 0);
    }
  }

  TransferActivityAlert _liveActivityAlert(TransferActivitySnapshot outcome) {
    final total = outcome.totalCount;
    final noun = total == 1 ? 'file' : 'files';
    return switch (outcome.phase) {
      TransferActivityPhase.completed => (
        title: 'Upload complete',
        body: '$total $noun uploaded successfully.',
      ),
      TransferActivityPhase.partial => (
        title: 'Upload finished',
        body:
            '${outcome.completedCount} uploaded, ${outcome.failedCount} failed.',
      ),
      _ => (
        title: 'Upload failed',
        body:
            '${outcome.failedCount} ${outcome.failedCount == 1 ? 'file' : 'files'} could not be uploaded.',
      ),
    };
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
