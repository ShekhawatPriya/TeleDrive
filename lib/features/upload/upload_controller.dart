import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http_parser/http_parser.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import 'upload_models.dart';
import 'upload_picker_helper.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';

final uploadControllerProvider = ChangeNotifierProvider<UploadController>((ref) {
  return UploadController(
    ref.read(apiClientProvider),
    ref.read(driveControllerProvider),
  );
});

class UploadController extends ChangeNotifier {
  UploadController(this._api, this._drive);

  static const maxFiles = 50;
  static const pollInterval = Duration(milliseconds: 1200);

  final ApiClient _api;
  final DriveController _drive;
  final _uuid = const Uuid();
  final Map<String, CancelToken> _cancelTokensByLocalId = {};
  final Map<int, Timer> _pollTimersByBatchId = {};
  final Set<int> _pollingBatchIds = {};
  final Set<String> _runningLocalIds = {};
  final Map<int, DateTime> _batchUploadFinishedTimes = {};
  Timer? _autoDismissTimer;
  String? _refreshedUploadSessionId;
  bool _disposed = false;

  String? uploadSessionId;
  List<UploadItem> items = [];
  bool picking = false;
  bool uploading = false;
  bool sheetVisible = false;
  String? activeFolderId;
  String? error;

  int get uploadedCount => items.where((i) => i.status == UploadStatus.uploaded).length;
  int get failedCount => items.where((i) => i.status == UploadStatus.failed || i.status == UploadStatus.cancelled).length;
  int get activeCount => items.where(_isActive).length;

  Future<void> pickFiles({String? folderId}) async {
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickFiles(maxFiles: maxFiles),
      'Document picking failed.',
    );
  }

  Future<void> pickPhoto({String? folderId}) async {
    activeFolderId = folderId;
    await _handlePicker(
      () => UploadPickerHelper.pickPhoto(),
      'Camera capture failed.',
    );
  }

  Future<void> _handlePicker(Future<UploadPickerResult> Function() pickAction, String defaultErrorMessage) async {
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

  void _pumpQueue() {
    if (_runningLocalIds.isNotEmpty) return;
    final next = items.where((i) => i.status == UploadStatus.queued).take(maxFiles).toList();
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
      form.fields.add(MapEntry('upload_client_id', uploadSessionId ?? _uuid.v4()));

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
      pollInterval,
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
        final matched = files.where((f) => f['upload_job_id'] == current.uploadJobId).firstOrNull;
        if (matched == null) continue;
        final status = UploadStatus.fromBackendStatus('${matched['status']}');
        final total = (matched['total_bytes'] as num?)?.toDouble() ?? current.size.toDouble();
        final done = (matched['progress_bytes'] as num?)?.toDouble() ?? 0;
        final serverProgress = status == UploadStatus.uploaded
            ? 1.0
            : total > 0
                ? (done / total).clamp(0.0, 1.0)
                : current.serverProgress;
        final thumbReady = '${matched['thumbnail_status'] ?? ''}' == 'available';
        if (status == UploadStatus.uploaded && current.status != UploadStatus.uploaded) {
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
      final allUploaded = updated.isNotEmpty && updated.every((i) => _isTerminalStatus(i.status));
      if (allUploaded) {
        final finishedTime = _batchUploadFinishedTimes.putIfAbsent(batchId, () => DateTime.now());
        final elapsedSeconds = DateTime.now().difference(finishedTime).inSeconds;

        final allDone = updated.every((i) => !_needsThumbnail(i)) || elapsedSeconds > 25;
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

  Future<void> cancelItem(String localId) async {
    final item = _findItem(localId);
    if (item == null || _isTerminalStatus(item.status)) return;
    _setItem(localId, status: UploadStatus.cancelling, cancelRequested: true);
    _cancelTokensByLocalId[localId]?.cancel('Upload cancelled.');

    if (item.batchId != null) {
      final endpoint = item.uploadJobId == null
          ? '/upload-batches/${item.batchId}/cancel'
          : '/upload-jobs/${item.uploadJobId}/cancel';
      await _api.dio.post(endpoint).catchError((_) => Response(requestOptions: RequestOptions()));
    } else {
      await _api.dio
          .post(
            '/files/upload/cancel',
            data: {'upload_client_id': item.uploadClientId},
          )
          .catchError((_) => Response(requestOptions: RequestOptions()));
    }

    if (item.batchId != null) _stopPollingBatch(item.batchId!);
    _runningLocalIds.remove(localId);
    _setItem(localId, status: UploadStatus.cancelled);
    unawaited(_safeDeleteLocalFile(item.path));
    _syncOptimistic();
    _pumpQueue();
  }

  Future<void> cancelUpload() async {
    final activeIds = items.where((i) => _isActive(i) || i.status == UploadStatus.selected).map((i) => i.localId).toList();
    for (final id in activeIds) {
      await cancelItem(id);
    }
    await _refreshDrive();
  }

  Future<void> retryFailed() async {
    items = items
        .map(
          (i) => i.status == UploadStatus.failed || i.status == UploadStatus.cancelled
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
    if (item.status != UploadStatus.failed && item.status != UploadStatus.cancelled) {
      return;
    }
    unawaited(_safeDeleteLocalFile(item.path));
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
      _safeDeleteLocalFile(item.path);
    }
    items = [];
    sheetVisible = false;
    uploadSessionId = null;
    error = null;
    _syncOptimistic();
    _notifyListeners();
  }

  UploadItem? _findItem(String localId) => items.where((i) => i.localId == localId).firstOrNull;

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
    return i.status == UploadStatus.uploaded && previewable && !i.thumbnailReady;
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
    final serverFileIds = _drive.state.files.where((f) => !f.isOptimistic).map((f) => f.id).toSet();
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

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
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

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _pollTimersByBatchId.values) {
      timer.cancel();
    }
    _cancelCompletionTimers();
    _pollingBatchIds.clear();
    for (final token in _cancelTokensByLocalId.values) {
      token.cancel();
    }
    super.dispose();
  }
}
