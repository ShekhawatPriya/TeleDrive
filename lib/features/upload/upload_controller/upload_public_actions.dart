part of '../upload_controller.dart';

extension _UploadPublicActions on UploadController {
  Future<void> _pickPhotos({String? folderId, BuildContext? context}) async {
    if (picking || uploading) return;
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickPhotos(maxFiles: UploadController.maxFiles),
      'Photo picking failed.',
      context: context,
    );
  }

  Future<void> _pickFiles({String? folderId, BuildContext? context}) async {
    if (picking || uploading) return;
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickFiles(maxFiles: UploadController.maxFiles),
      'Document picking failed.',
      context: context,
    );
  }

  Future<void> _pickPhoto({String? folderId, BuildContext? context}) async {
    if (picking || uploading) return;
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickPhoto(),
      'Camera capture failed.',
      context: context,
    );
  }

  Future<void> _confirmUpload() async {
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

  Future<void> _enqueueGalleryBackupItems(List<UploadItem> backupItems) async {
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
    _bumpItemsVersion();
    _syncOptimistic();
    _notifyListeners();
    _pumpQueue();
  }

  Future<void> _pauseQueuedGalleryBackupItems() async {
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
    _bumpItemsVersion();
    _syncOptimistic();
    _updateUploadingFlag();
    _notifyListeners();
  }

  Future<void> _cancelItem(String localId) async {
    final item = _findItem(localId);
    if (item == null || _isTerminalStatus(item.status)) return;
    _setItem(localId, status: UploadStatus.cancelling, cancelRequested: true);
    unawaited(_telegram.cancelTransfer(item.uploadClientId));

    if (item.batchId != null) {
      final endpoint = item.uploadJobId == null
          ? '/upload-batches/${item.batchId}/cancel'
          : '/upload-jobs/${item.uploadJobId}/cancel';
      await _api.dio
          .post(endpoint)
          .catchError((_) => Response(requestOptions: RequestOptions()));
    }

    _runningLocalIds.remove(localId);
    _setItem(localId, status: UploadStatus.cancelled);
    if (item.deleteLocalOnComplete) {
      unawaited(_safeDeleteLocalFile(item.path));
    }
    _syncOptimistic();
    _pumpQueue();
  }

  Future<void> _cancelUpload() async {
    final activeIds = items
        .where((i) => _isActive(i) || i.status == UploadStatus.selected)
        .map((i) => i.localId)
        .toList();
    for (final id in activeIds) {
      await cancelItem(id);
    }
    await _refreshDrive();
  }

  Future<void> _retryFailed() async {
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

  void _removeFailed(String localId) {
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
    _bumpItemsVersion();
    if (items.isEmpty) {
      sheetVisible = false;
      uploadSessionId = null;
      error = null;
    }
    _syncOptimistic();
    _notifyListeners();
  }

  void _dismiss() {
    if (uploading) return;
    for (final item in items) {
      if (item.deleteLocalOnComplete) {
        _safeDeleteLocalFile(item.path);
      }
    }
    items = [];
    _bumpItemsVersion();
    sheetVisible = false;
    uploadSessionId = null;
    error = null;
    _syncOptimistic();
    _notifyListeners(force: true);
  }

  void _resetTerminalForAccountSwitch() {
    if (hasBlockingUploads) return;
    _cancelCompletionTimers();
    items = [];
    _bumpItemsVersion();
    sheetVisible = false;
    uploadSessionId = null;
    activeFolderId = null;
    error = null;
    uploading = false;
    _syncOptimistic();
    _notifyListeners(force: true);
  }

  Future<void> _enableMobileDataUploads() async {
    await _settings.setUploadOnMobileData(true);
    if (_disposed) return;
    _resumeWaitingUploads();
  }
}
