part of '../upload_controller.dart';

extension _UploadStateSync on UploadController {
  UploadItem? _findItem(String localId) =>
      items.where((i) => i.localId == localId).firstOrNull;

  bool _isActive(UploadItem item) => {
    UploadStatus.queued,
    UploadStatus.stagingToBackend,
    UploadStatus.waitingForServer,
    UploadStatus.uploadingToTelegram,
    UploadStatus.processing,
    UploadStatus.cancelling,
  }.contains(item.status);

  bool _isTerminalStatus(UploadStatus status) => {
    UploadStatus.uploaded,
    UploadStatus.cancelled,
    UploadStatus.failed,
  }.contains(status);

  void _setItem(
    String localId, {
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
  }) {
    items = items
        .map(
          (i) => i.localId == localId
              ? i.copyWith(
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
    _syncOptimistic();
    _updateUploadingFlag();
    _notifyListeners();
  }

  void _setItemProgress(String localId, {double? httpProgress}) {
    _setItem(localId, httpProgress: httpProgress);
  }

  void _stopPollingBatch(int batchId) {
    _pollTimersByBatchId.remove(batchId)?.cancel();
    _pollingBatchIds.remove(batchId);
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
    if (uploading || !items.any((i) => i.status == UploadStatus.uploaded)) {
      return;
    }
    final sessionId = uploadSessionId;
    if (sessionId != null && _refreshedUploadSessionId != sessionId) {
      _refreshedUploadSessionId = sessionId;
      await _refreshDrive();
    }
    if (_allItemsCompleted) {
      _scheduleAutoDismiss();
    }
  }

  void _scheduleAutoDismiss() {
    final sessionId = uploadSessionId;
    if (sessionId == null || _autoDismissTimer?.isActive == true) return;
    _autoDismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (_disposed || uploadSessionId != sessionId || uploading) return;
      if (!_allItemsCompleted) return;
      for (final item in items) {
        _safeDeleteLocalFile(item.path);
      }
      items = [];
      sheetVisible = false;
      uploadSessionId = null;
      error = null;
      _syncOptimistic();
      _notifyListeners();
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
