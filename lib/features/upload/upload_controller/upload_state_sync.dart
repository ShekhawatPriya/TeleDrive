part of '../upload_controller.dart';

enum _OptimisticBucket {
  activeOrQueued,
  terminalFailed,
  uploadedWithoutFileId,
  uploadedWithFileId,
}

extension _UploadStateSync on UploadController {
  UploadItem? _findItem(String localId) =>
      items.where((i) => i.localId == localId).firstOrNull;

  bool _isActive(UploadItem item) => {
    UploadStatus.queued,
    UploadStatus.waitingForWifi,
    UploadStatus.preparingMetadata,
    UploadStatus.creatingThumbnail,
    UploadStatus.creatingPreview,
    UploadStatus.uploadingOriginalToTelegram,
    UploadStatus.uploadingThumbnailToTelegram,
    UploadStatus.uploadingPreviewToTelegram,
    UploadStatus.committingMetadata,
    UploadStatus.cancelling,
  }.contains(item.status);

  bool _isTerminalStatus(UploadStatus status) => {
    UploadStatus.uploaded,
    UploadStatus.cancelled,
    UploadStatus.failed,
  }.contains(status);

  void _bumpItemsVersion() {
    _itemsVersion++;
  }

  _OptimisticBucket _bucketFor(UploadItem item) {
    final s = item.status;
    if (s == UploadStatus.cancelled || s == UploadStatus.failed) {
      return _OptimisticBucket.terminalFailed;
    }
    if (s == UploadStatus.uploaded) {
      return item.fileId == null
          ? _OptimisticBucket.uploadedWithoutFileId
          : _OptimisticBucket.uploadedWithFileId;
    }
    return _OptimisticBucket.activeOrQueued;
  }

  ({String localId, _OptimisticBucket bucket, int? fileId, bool thumbnailReady})
  _optimisticSignature(UploadItem item) => (
    localId: item.localId,
    bucket: _bucketFor(item),
    fileId: item.fileId,
    thumbnailReady: item.thumbnailReady,
  );

  Set<
    ({
      String localId,
      _OptimisticBucket bucket,
      int? fileId,
      bool thumbnailReady,
    })
  >
  _optimisticSignatureSet() => items.map(_optimisticSignature).toSet();

  void _setItem(
    String localId, {
    String? name,
    UploadStatus? status,
    double? httpProgress,
    double? serverProgress,
    int? batchId,
    int? fileId,
    int? uploadJobId,
    String? error,
    bool clearError = false,
    bool? cancelRequested,
    bool? thumbnailReady,
    String? thumbnailUrl,
    bool notify = true,
  }) {
    final before = notify ? _optimisticSignatureSet() : null;
    items = items
        .map(
          (i) => i.localId == localId
              ? i.copyWith(
                  name: name,
                  status: status,
                  httpProgress: httpProgress,
                  serverProgress: serverProgress,
                  batchId: batchId,
                  fileId: fileId,
                  uploadJobId: uploadJobId,
                  error: error,
                  clearError: clearError,
                  cancelRequested: cancelRequested,
                  thumbnailReady: thumbnailReady,
                  thumbnailUrl: thumbnailUrl,
                )
              : i,
        )
        .toList();
    if (!notify) return;
    final isTerminal = status != null && _isTerminalStatus(status);
    _syncOptimisticThrottled(
      previousSignatures: before,
      forceImmediate: isTerminal,
    );
    _updateUploadingFlag();
    _notifyListeners(force: isTerminal);
  }

  void _flushSetItemBatch({bool force = false}) {
    _syncOptimistic();
    _updateUploadingFlag();
    _notifyListeners(force: force);
  }

  void _updateUploadingFlag() {
    uploading = items.any(_isActive) || _runningLocalIds.isNotEmpty;
  }

  bool _needsThumbnail(UploadItem i) {
    final kind = detectFileKind(i.name, i.mimeType);
    final previewable = kind == FileKind.image || kind == FileKind.video;
    return i.status == UploadStatus.uploaded &&
        previewable &&
        !i.thumbnailReady;
  }

  bool get _allItemsCompleted {
    if (items.isEmpty) return false;
    return items.every((i) {
      if (i.status != UploadStatus.uploaded) return false;
      return !_needsThumbnail(i);
    });
  }

  Future<void> _refreshIfSettled() async {
    _updateUploadingFlag();
    if (uploading) {
      return;
    }
    if (items.every((i) => _isTerminalStatus(i.status))) {
      unawaited(_notifyUploadSettledIfNeeded());
    }
    if (!items.any((i) => i.status == UploadStatus.uploaded)) return;
    final sessionId = uploadSessionId;
    if (sessionId != null && _refreshedUploadSessionId != sessionId) {
      _refreshedUploadSessionId = sessionId;
      // _refreshDrive only reloads root + the active folder. Uploads that
      // targeted another folder (destination picker) need their pages
      // refreshed too, so their optimistic rows are replaced by server rows
      // before the sheet auto-dismiss strips them.
      final destinations = items
          .where((i) => i.status == UploadStatus.uploaded)
          .map((i) => i.destinationFolderId ?? activeFolderId)
          .toSet();
      for (final dest in destinations) {
        if (dest != null && dest != _drive.state.activeFolderId) {
          unawaited(_drive.refreshFolder(dest));
        }
      }
      await _refreshDrive();
    }
    if (_allItemsCompleted) {
      unawaited(_notifyUploadSettledIfNeeded());
      _scheduleAutoDismiss();
    } else if (items.every((i) => _isTerminalStatus(i.status))) {
      unawaited(_notifyUploadSettledIfNeeded());
    }
  }

  void _scheduleAutoDismiss() {
    final sessionId = uploadSessionId;
    if (sessionId == null || _autoDismissTimer?.isActive == true) return;
    _autoDismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (_disposed || uploadSessionId != sessionId || uploading) return;
      if (!_allItemsCompleted) return;
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
    });
  }

  void _cancelCompletionTimers() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _refreshedUploadSessionId = null;
  }

  Future<void> _refreshDrive() async {
    try {
      await _drive.refresh(silent: true, force: true);
    } catch (_) {}
  }

  void _syncOptimistic() {
    _optimisticSyncTimer?.cancel();
    _optimisticSyncTimer = null;
    final serverFileIds = _drive.state.files
        .where((f) => !f.isOptimistic)
        .map((f) => f.id)
        .toSet();
    _drive.syncOptimisticUploads(
      items
          .where((i) {
            if (i.status != UploadStatus.uploaded) return true;
            if (i.fileId == null) return true;
            if (!serverFileIds.contains('${i.fileId}')) return true;
            if (_needsThumbnail(i)) return true;
            return false;
          })
          .map((i) => i.toDriveFile(activeFolderId))
          .toList(),
    );
  }

  void _syncOptimisticThrottled({
    Set<
      ({
        String localId,
        _OptimisticBucket bucket,
        int? fileId,
        bool thumbnailReady,
      })
    >?
    previousSignatures,
    bool forceImmediate = false,
  }) {
    if (forceImmediate) {
      _syncOptimistic();
      return;
    }
    final after = _optimisticSignatureSet();
    final structuralChange =
        previousSignatures == null ||
        previousSignatures.length != after.length ||
        !previousSignatures.containsAll(after) ||
        !after.containsAll(previousSignatures);
    if (structuralChange) {
      _syncOptimistic();
      return;
    }
    if (_optimisticSyncTimer?.isActive == true) return;
    _optimisticSyncTimer = Timer(const Duration(milliseconds: 250), () {
      _optimisticSyncTimer = null;
      if (_disposed) return;
      _syncOptimistic();
    });
  }

  Future<void> _safeDeleteLocalFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Successfully deleted temporary upload file: $path');
      }
    } catch (e) {
      debugPrint('Error deleting temporary upload file: $e');
    }
  }
}
