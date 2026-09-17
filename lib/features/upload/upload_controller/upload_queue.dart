part of '../upload_controller.dart';

extension _UploadQueue on UploadController {
  void _pumpQueue() {
    if (_disposed) return;
    final configuredConcurrency = AppConfig.maxConcurrentTelegramUploads;
    final concurrentLimit = configuredConcurrency < 1
        ? 1
        : configuredConcurrency > 2
        ? 2
        : configuredConcurrency;
    final availableSlots = concurrentLimit - _runningLocalIds.length;
    if (availableSlots <= 0) return;
    final firstQueued = items
        .where(
          (i) =>
              i.status == UploadStatus.queued &&
              !_runningLocalIds.contains(i.localId),
        )
        .firstOrNull;
    final nextFolderId = firstQueued?.destinationFolderId ?? activeFolderId;
    final next = items
        .where(
          (i) =>
              i.status == UploadStatus.queued &&
              !_runningLocalIds.contains(i.localId),
        )
        .where((i) => (i.destinationFolderId ?? activeFolderId) == nextFolderId)
        .take(availableSlots)
        .toList();
    if (next.isEmpty) {
      _updateUploadingFlag();
      _notifyListeners();
      return;
    }
    for (final item in next) {
      _runningLocalIds.add(item.localId);
    }
    unawaited(_uploadMany(next));
    _updateUploadingFlag();
    _notifyListeners();
  }

  Future<void> _uploadMany(List<UploadItem> batchItems) async {
    try {
      await _requireDirectUploadReady();
      await _uploadManyDirect(batchItems);
    } on TelegramClientException catch (err) {
      await _failBatchBeforeUpload(
        batchItems,
        _tdlibRequiredMessage(err.message),
        failureCode: err.code ?? 'tdlib_unavailable',
      );
    } catch (err) {
      await _failBatchBeforeUpload(
        batchItems,
        _tdlibRequiredMessage('$err'),
        failureCode: 'tdlib_unavailable',
      );
    }
  }

  Future<void> _requireDirectUploadReady() async {
    if (!_auth.directTelegramUploadEnabled) {
      throw const TelegramClientUnavailableException(
        'Local TDLib upload is not enabled by this backend.',
        code: 'tdlib_direct_upload_disabled',
      );
    }
    final user = _auth.user;
    if (user == null || user.telegramId == 0) {
      throw const TelegramClientUnavailableException(
        'Connect Telegram before uploading.',
        code: 'tdlib_not_connected',
      );
    }
    if (!await _telegram.isAvailable) {
      throw const TelegramClientUnavailableException(
        'TeleDrive requires a supported Android or iOS device for local TDLib file transfer.',
        code: 'tdlib_unavailable',
      );
    }
    try {
      await _telegram.configure(
        backendUserId: '${user.userId}',
        telegramUserId: user.telegramId,
      );
      if (!await _telegram.isAuthorized) {
        throw const TelegramClientUnavailableException(
          'Local TDLib is not authorized.',
          code: 'tdlib_auth_required',
        );
      }
      final me = await _telegram.getMe();
      final tdlibUserId = _intish(me['id']);
      if (tdlibUserId != null && tdlibUserId != user.telegramId) {
        throw const TelegramAccountMismatchException(
          'Local TDLib account does not match the active TeleDrive account.',
          code: 'tdlib_account_mismatch',
        );
      }
    } on TelegramClientException {
      rethrow;
    }
  }

  Future<void> _failBatchBeforeUpload(
    List<UploadItem> batchItems,
    String message, {
    required String failureCode,
  }) async {
    final scope = _backupScope();
    for (final item in batchItems) {
      _setItem(
        item.localId,
        status: UploadStatus.failed,
        error: message,
        notify: false,
      );
      _runningLocalIds.remove(item.localId);
      if (scope != null && item.backupFingerprint != null) {
        await _backupAssetStore.mark(
          scope,
          item.backupFingerprint!,
          GalleryBackupAssetStatus.failed,
          failureCode: failureCode,
          failureMessage: message,
        );
      }
    }
    _flushSetItemBatch(force: true);
    await _refreshIfSettled();
    _pumpQueue();
  }

  String _tdlibRequiredMessage(String detail) {
    final trimmed = detail.trim();
    final suffix = trimmed.isEmpty ? '' : ' $trimmed';
    return 'TeleDrive uses local TDLib for file transfer. Reconnect Telegram on this device to continue.$suffix';
  }
}
