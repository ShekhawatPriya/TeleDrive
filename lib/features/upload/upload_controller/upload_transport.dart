part of '../upload_controller.dart';

extension _UploadTransport on UploadController {
  void _pumpQueue() {
    if (_runningLocalIds.isNotEmpty) return;
    final next = items
        .where((i) => i.status == UploadStatus.queued)
        .take(UploadController.maxFiles)
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
    if (await _isBlockedOnMobileData()) {
      for (final item in batchItems) {
        _runningLocalIds.remove(item.localId);
        _setItem(item.localId, status: UploadStatus.waitingForWifi);
      }
      _updateUploadingFlag();
      _notifyListeners();
      return;
    }
    if (batchItems.length == 1) {
      await _uploadOne(batchItems.single);
      return;
    }
    final token = CancelToken();
    for (final item in batchItems) {
      _cancelTokensByLocalId[item.localId] = token;
      _setItem(
        item.localId,
        status: UploadStatus.stagingToBackend,
        httpProgress: 0,
        serverProgress: 0,
        clearError: true,
      );
    }

    try {
      final form = FormData();
      for (final item in batchItems) {
        form.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(
              item.path,
              filename: item.name,
              contentType: MediaType.parse(item.mimeType),
            ),
          ),
        );
      }
      if (activeFolderId != null) {
        form.fields.add(MapEntry('folder_id', activeFolderId!));
      }
      form.fields.add(
        MapEntry('upload_client_id', uploadSessionId ?? _uuid.v4()),
      );
      form.fields.add(
        MapEntry(
          'auto_rename_duplicates',
          _settings.state.autoRenameDuplicates.toString(),
        ),
      );

      final res = await _api.dio.post(
        '/files/upload',
        data: form,
        cancelToken: token,
        onSendProgress: (sent, total) {
          final progress = total <= 0 ? 0.05 : (sent / total).clamp(0.0, 1.0);
          for (final item in batchItems) {
            _setItemProgress(item.localId, httpProgress: progress);
          }
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final batchId = (data['batch_id'] as num).toInt();
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (var index = 0; index < batchItems.length; index++) {
        final item = batchItems[index];
        final file = index < files.length ? files[index] : <String, dynamic>{};
        final current = _findItem(item.localId);
        if (current == null || current.cancelRequested) continue;
        _setItem(
          item.localId,
          name: file['filename'] as String?,
          status: UploadStatus.waitingForServer,
          httpProgress: 1,
          batchId: batchId,
          fileId: (file['file_id'] as num?)?.toInt(),
          uploadJobId: (file['upload_job_id'] as num?)?.toInt(),
        );
      }
      _startPollingBatch(batchId);
      await _pollBatch(batchId);
    } catch (err) {
      final cancelled = err is DioException && CancelToken.isCancel(err);
      for (final item in batchItems) {
        _setItem(
          item.localId,
          status: cancelled ? UploadStatus.cancelled : UploadStatus.failed,
          error: cancelled ? null : _api.errorMessage(err, 'Upload failed.'),
        );
      }
    } finally {
      for (final item in batchItems) {
        _cancelTokensByLocalId.remove(item.localId);
        _runningLocalIds.remove(item.localId);
      }
      _syncOptimistic();
      await _refreshIfSettled();
      _pumpQueue();
    }
  }

  Future<void> _uploadOne(UploadItem item) async {
    if (await _isBlockedOnMobileData()) {
      _runningLocalIds.remove(item.localId);
      _setItem(item.localId, status: UploadStatus.waitingForWifi);
      _updateUploadingFlag();
      _notifyListeners();
      return;
    }
    final token = CancelToken();
    _cancelTokensByLocalId[item.localId] = token;
    _setItem(
      item.localId,
      status: UploadStatus.stagingToBackend,
      httpProgress: 0,
      serverProgress: 0,
      clearError: true,
    );

    try {
      final form = FormData();
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(
            item.path,
            filename: item.name,
            contentType: MediaType.parse(item.mimeType),
          ),
        ),
      );
      if (activeFolderId != null) {
        form.fields.add(MapEntry('folder_id', activeFolderId!));
      }
      form.fields.add(MapEntry('upload_client_id', item.uploadClientId));
      form.fields.add(
        MapEntry(
          'auto_rename_duplicates',
          _settings.state.autoRenameDuplicates.toString(),
        ),
      );

      final res = await _api.dio.post(
        '/files/upload',
        data: form,
        cancelToken: token,
        onSendProgress: (sent, total) {
          _setItemProgress(
            item.localId,
            httpProgress: total <= 0 ? 0.05 : (sent / total).clamp(0.0, 1.0),
          );
        },
      );
      final current = _findItem(item.localId);
      if (current == null || current.cancelRequested) return;
      final data = Map<String, dynamic>.from(res.data as Map);
      final batchId = (data['batch_id'] as num).toInt();
      final file = Map<String, dynamic>.from(
        ((data['files'] as List?)?.first ?? {}) as Map,
      );
      _setItem(
        item.localId,
        name: file['filename'] as String?,
        status: UploadStatus.waitingForServer,
        httpProgress: 1,
        batchId: batchId,
        fileId: (file['file_id'] as num?)?.toInt(),
        uploadJobId: (file['upload_job_id'] as num?)?.toInt(),
      );
      _startPollingBatch(batchId);
      await _pollBatch(batchId);
    } catch (err) {
      if (err is DioException && CancelToken.isCancel(err)) {
        _setItem(item.localId, status: UploadStatus.cancelled);
      } else {
        _setItem(
          item.localId,
          status: UploadStatus.failed,
          error: _api.errorMessage(err, 'Upload failed.'),
        );
      }
    } finally {
      _cancelTokensByLocalId.remove(item.localId);
      _runningLocalIds.remove(item.localId);
      _syncOptimistic();
      await _refreshIfSettled();
      _pumpQueue();
    }
  }

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
          unawaited(_safeDeleteLocalFile(current.path));
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
