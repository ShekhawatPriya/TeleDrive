part of '../upload_controller.dart';

extension _UploadPolling on UploadController {
  String _directBatchUploadClientId(List<UploadItem> batchItems) {
    final sessionId = uploadSessionId ??= _uuid.v4();
    final chunkId = batchItems.map((item) => item.localId).join(',');
    return '$sessionId:$chunkId';
  }

  // ignore: unused_element
  void _startPollingBatch(int batchId) {
    _stopPollingBatch(batchId);
    _pollTimersByBatchId[batchId] = Timer.periodic(
      UploadController.pollInterval,
      (_) => _pollBatch(batchId),
    );
  }

  Future<void> _pollBatch(int batchId) async {
    final batchItems = items.where((i) => i.batchId == batchId).toList();
    if (batchItems.isEmpty || !_pollingBatchIds.add(batchId)) return;
    try {
      final res = await _api.dio.get('/upload-batches/$batchId');
      final data = Map<String, dynamic>.from(res.data as Map);
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final current in batchItems) {
        if (current.cancelRequested) continue;
        final matched = files
            .where((f) => f['upload_job_id'] == current.uploadJobId)
            .firstOrNull;
        if (matched == null) continue;
        final status = UploadStatus.fromBackendStatus('${matched['status']}');
        final total =
            (matched['total_bytes'] as num?)?.toDouble() ??
            current.size.toDouble();
        final done = (matched['progress_bytes'] as num?)?.toDouble() ?? 0;
        final serverProgress = status == UploadStatus.uploaded
            ? 1.0
            : total > 0
            ? (done / total).clamp(0.0, 1.0)
            : current.serverProgress;
        final thumbReady =
            '${matched['thumbnail_status'] ?? ''}' == 'available';
        if (status == UploadStatus.uploaded &&
            current.status != UploadStatus.uploaded) {
          if (current.deleteLocalOnComplete) {
            unawaited(_safeDeleteLocalFile(current.path));
          }
        }
        _setItem(
          current.localId,
          status: status,
          serverProgress: serverProgress,
          fileId: (matched['file_id'] as num?)?.toInt(),
          error: matched['error'] as String?,
          thumbnailReady: thumbReady,
        );
      }
      final updated = items.where((i) => i.batchId == batchId).toList();
      final allUploaded =
          updated.isNotEmpty &&
          updated.every((i) => _isTerminalStatus(i.status));
      if (allUploaded) {
        final finishedTime = _batchUploadFinishedTimes.putIfAbsent(
          batchId,
          () => DateTime.now(),
        );
        final elapsedSeconds = DateTime.now()
            .difference(finishedTime)
            .inSeconds;
        final allDone =
            updated.every((i) => !_needsThumbnail(i)) || elapsedSeconds > 25;
        if (allDone) {
          _stopPollingBatch(batchId);
          _batchUploadFinishedTimes.remove(batchId);
          await _refreshIfSettled();
        }
      }
    } catch (err) {
      _stopPollingBatch(batchId);
      for (final item in batchItems) {
        _setItem(
          item.localId,
          status: UploadStatus.failed,
          error: _api.errorMessage(err, 'Upload polling failed.'),
        );
      }
      await _refreshIfSettled();
    } finally {
      _pollingBatchIds.remove(batchId);
    }
  }
}
