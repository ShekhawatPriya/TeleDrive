import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/file_type_detector.dart';
import '../../core/utils/iterable_ext.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';

final uploadControllerProvider = ChangeNotifierProvider<UploadController>((
  ref,
) {
  return UploadController(
    ref.read(apiClientProvider),
    ref.read(driveControllerProvider),
  );
});

enum UploadStatus {
  selected,
  queued,
  stagingToBackend,
  waitingForServer,
  uploadingToTelegram,
  processing,
  uploaded,
  cancelling,
  cancelled,
  failed,
}

class UploadItem {
  UploadItem({
    required this.localId,
    required this.uploadClientId,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.path,
    required this.status,
    this.httpProgress = 0,
    this.serverProgress = 0,
    this.batchId,
    this.fileId,
    this.uploadJobId,
    this.error,
    this.cancelRequested = false,
    this.thumbnailReady = false,
    this.thumbnailUrl,
  }) : progress = _computeProgress(status, httpProgress, serverProgress);

  final String localId;
  final String uploadClientId;
  final String name;
  final int size;
  final String mimeType;
  final String path;
  final UploadStatus status;
  final double httpProgress;
  final double serverProgress;
  final double progress;
  final int? batchId;
  final int? fileId;
  final int? uploadJobId;
  final String? error;
  final bool cancelRequested;
  final bool thumbnailReady;
  final String? thumbnailUrl;

  static double _computeProgress(
    UploadStatus status,
    double http,
    double server,
  ) {
    switch (status) {
      case UploadStatus.uploaded:
        return 1.0;
      case UploadStatus.selected:
      case UploadStatus.queued:
        return 0.0;
      case UploadStatus.stagingToBackend:
        return (http * 0.4).clamp(0.0, 0.4);
      case UploadStatus.waitingForServer:
      case UploadStatus.uploadingToTelegram:
      case UploadStatus.processing:
        return (0.4 + server * 0.6).clamp(0.0, 1.0);
      case UploadStatus.cancelling:
      case UploadStatus.cancelled:
      case UploadStatus.failed:
        return ((http * 0.4) + (server * 0.6)).clamp(0.0, 1.0);
    }
  }

  UploadItem copyWith({
    String? uploadClientId,
    UploadStatus? status,
    double? httpProgress,
    double? serverProgress,
    int? batchId,
    int? fileId,
    int? uploadJobId,
    String? error,
    bool clearError = false,
    bool? cancelRequested,
    bool resetServerIds = false,
    bool? thumbnailReady,
    String? thumbnailUrl,
    bool clearThumbnail = false,
  }) {
    return UploadItem(
      localId: localId,
      uploadClientId: uploadClientId ?? this.uploadClientId,
      name: name,
      size: size,
      mimeType: mimeType,
      path: path,
      status: status ?? this.status,
      httpProgress: httpProgress ?? this.httpProgress,
      serverProgress: serverProgress ?? this.serverProgress,
      batchId: resetServerIds ? null : batchId ?? this.batchId,
      fileId: resetServerIds ? null : fileId ?? this.fileId,
      uploadJobId: resetServerIds ? null : uploadJobId ?? this.uploadJobId,
      error: clearError ? null : error ?? this.error,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      thumbnailReady: clearThumbnail
          ? false
          : thumbnailReady ?? this.thumbnailReady,
      thumbnailUrl: clearThumbnail
          ? null
          : thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}

class UploadController extends ChangeNotifier {
  UploadController(this._api, this._drive);

  static const maxFiles = 50;
  static const pollInterval = Duration(milliseconds: 1200);

  final ApiClient _api;
  final DriveController _drive;
  final _uuid = const Uuid();
  final Map<String, CancelToken> _cancelTokensByLocalId = {};
  final Map<String, Timer> _pollTimersByLocalId = {};
  final Map<int, Timer> _pollTimersByBatchId = {};
  final Set<String> _pollingLocalIds = {};
  final Set<int> _pollingBatchIds = {};
  final Set<String> _runningLocalIds = {};
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

  Future<void> pickFiles({String? folderId}) async {
    if (picking || uploading) return;
    picking = true;
    error = null;
    activeFolderId = folderId;
    _notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      if (result.files.length > maxFiles) {
        error = 'Select at most $maxFiles files at once.';
        sheetVisible = true;
        return;
      }
      final usableFiles = result.files.where((f) => f.path != null).toList();
      if (usableFiles.isEmpty) {
        error =
            'The selected file did not expose a local path. Try picking from device storage or Downloads.';
        sheetVisible = true;
        return;
      }
      uploadSessionId = _uuid.v4();
      items = usableFiles.map((file) {
        final mime =
            lookupMimeType(file.path!, headerBytes: null) ??
            'application/octet-stream';
        return UploadItem(
          localId: _uuid.v4(),
          uploadClientId: _uuid.v4(),
          name: file.name,
          size: file.size,
          mimeType: mime,
          path: file.path!,
          status: UploadStatus.selected,
        );
      }).toList();
      sheetVisible = items.isNotEmpty;
      _syncOptimistic();
      await confirmUpload();
    } catch (err) {
      error = _api.errorMessage(err, 'Document picking failed.');
      sheetVisible = true;
    } finally {
      picking = false;
      _notifyListeners();
    }
  }

  Future<void> pickPhoto({String? folderId}) async {
    if (picking || uploading) return;
    picking = true;
    error = null;
    activeFolderId = folderId;
    _notifyListeners();
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final mime = lookupMimeType(photo.path) ?? 'image/jpeg';
      uploadSessionId = _uuid.v4();
      items = [
        UploadItem(
          localId: _uuid.v4(),
          uploadClientId: _uuid.v4(),
          name: photo.name,
          size: await photo.length(),
          mimeType: mime,
          path: photo.path,
          status: UploadStatus.selected,
        ),
      ];
      sheetVisible = items.isNotEmpty;
      _syncOptimistic();
      await confirmUpload();
    } catch (err) {
      error = _api.errorMessage(err, 'Camera capture failed.');
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
    final next = items
        .where((i) => i.status == UploadStatus.queued)
        .take(maxFiles)
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
        ((data['files'] as List?)?.firstOrNull ?? {}) as Map,
      );
      _setItem(
        item.localId,
        status: UploadStatus.waitingForServer,
        httpProgress: 1,
        batchId: batchId,
        fileId: (file['file_id'] as num?)?.toInt(),
        uploadJobId: (file['upload_job_id'] as num?)?.toInt(),
      );
      _startPollingItem(item.localId, batchId);
      await _pollItem(item.localId, batchId);
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

  void _startPollingItem(String localId, int batchId) {
    _stopPollingItem(localId);
    _pollTimersByLocalId[localId] = Timer.periodic(
      pollInterval,
      (_) => _pollItem(localId, batchId),
    );
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
        final matched = files
            .where((f) => f['upload_job_id'] == current.uploadJobId)
            .firstOrNull;
        if (matched == null) continue;
        final status = _toUploadStatus('${matched['status']}');
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
      if (updated.isNotEmpty &&
          updated.every((i) => _isTerminalStatus(i.status))) {
        _stopPollingBatch(batchId);
        await _refreshIfSettled();
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

  Future<void> _pollItem(String localId, int batchId) async {
    final item = _findItem(localId);
    if (item == null || item.cancelRequested) return;
    if (!_pollingLocalIds.add(localId)) return;
    try {
      final res = await _api.dio.get('/upload-batches/$batchId');
      final data = Map<String, dynamic>.from(res.data as Map);
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final current = _findItem(localId);
      if (current == null) return;
      final matched = files
          .where((f) => f['upload_job_id'] == current.uploadJobId)
          .firstOrNull;
      if (matched == null) return;
      final status = _toUploadStatus('${matched['status']}');
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
      _setItem(
        localId,
        status: status,
        serverProgress: serverProgress,
        fileId: (matched['file_id'] as num?)?.toInt(),
        error: matched['error'] as String?,
        thumbnailReady: thumbReady,
      );
      if (_isTerminalStatus(status)) {
        _stopPollingItem(localId);
        await _refreshIfSettled();
      }
    } catch (err) {
      _stopPollingItem(localId);
      _setItem(
        localId,
        status: UploadStatus.failed,
        error: _api.errorMessage(err, 'Upload polling failed.'),
      );
      await _refreshIfSettled();
    } finally {
      _pollingLocalIds.remove(localId);
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
      await _api.dio
          .post(endpoint)
          .catchError((_) => Response(requestOptions: RequestOptions()));
    } else {
      await _api.dio
          .post(
            '/files/upload/cancel',
            data: {'upload_client_id': item.uploadClientId},
          )
          .catchError((_) => Response(requestOptions: RequestOptions()));
    }

    _stopPollingItem(localId);
    if (item.batchId != null) _stopPollingBatch(item.batchId!);
    _runningLocalIds.remove(localId);
    _setItem(localId, status: UploadStatus.cancelled);
    _syncOptimistic();
    _pumpQueue();
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

  void dismiss() {
    if (uploading) return;
    for (final timer in _pollTimersByLocalId.values) {
      timer.cancel();
    }
    _pollTimersByLocalId.clear();
    for (final timer in _pollTimersByBatchId.values) {
      timer.cancel();
    }
    _pollTimersByBatchId.clear();
    items = [];
    sheetVisible = false;
    uploadSessionId = null;
    error = null;
    _syncOptimistic();
    _notifyListeners();
  }

  UploadStatus _toUploadStatus(String status) {
    if (status == 'completed' || status == 'available') {
      return UploadStatus.uploaded;
    }
    if (status == 'cancelled') return UploadStatus.cancelled;
    if (status == 'failed') return UploadStatus.failed;
    if (status == 'uploading' || status == 'uploading_original') {
      return UploadStatus.uploadingToTelegram;
    }
    if (status.startsWith('processing') || status == 'derivatives') {
      return UploadStatus.processing;
    }
    return UploadStatus.waitingForServer;
  }

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

  void _stopPollingItem(String localId) {
    _pollTimersByLocalId.remove(localId)?.cancel();
    _pollingLocalIds.remove(localId);
  }

  void _stopPollingBatch(int batchId) {
    _pollTimersByBatchId.remove(batchId)?.cancel();
    _pollingBatchIds.remove(batchId);
  }

  void _updateUploadingFlag() {
    uploading = items.any(_isActive) || _runningLocalIds.isNotEmpty;
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
    if (_allItemsUploaded) {
      _scheduleAutoDismiss();
    }
  }

  bool get _allItemsUploaded =>
      items.isNotEmpty && items.every((i) => i.status == UploadStatus.uploaded);

  void _scheduleAutoDismiss() {
    final sessionId = uploadSessionId;
    if (sessionId == null || _autoDismissTimer?.isActive == true) return;
    _autoDismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (_disposed || uploadSessionId != sessionId || uploading) return;
      if (!_allItemsUploaded) return;
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
    } catch (_) {
      // Drive refresh already owns its user-facing error state.
    }
  }

  void _syncOptimistic() {
    _drive.syncOptimisticUploads(
      items.where((i) => i.status != UploadStatus.selected).map((i) {
        final kind = detectFileKind(i.name, i.mimeType);
        return DriveFile(
          id: i.fileId == null ? 'local:${i.localId}' : '${i.fileId}',
          name: i.name,
          kind: kind,
          size: i.size,
          modifiedAt: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
          parentId: activeFolderId,
          starred: false,
          mimeType: i.mimeType,
          uploadStatus: i.status.name,
          uploadError: i.error,
          localUri: i.path,
          thumbnailUrl: kind == FileKind.image || kind == FileKind.video
              ? i.path
              : null,
          previewUrl: kind == FileKind.image ? i.path : null,
          isOptimistic: true,
        );
      }).toList(),
    );
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _pollTimersByLocalId.values) {
      timer.cancel();
    }
    for (final timer in _pollTimersByBatchId.values) {
      timer.cancel();
    }
    _cancelCompletionTimers();
    _pollingLocalIds.clear();
    _pollingBatchIds.clear();
    for (final token in _cancelTokensByLocalId.values) {
      token.cancel();
    }
    super.dispose();
  }
}
