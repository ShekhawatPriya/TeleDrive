import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http_parser/http_parser.dart';
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
    ref.watch(apiClientProvider),
    ref.watch(driveControllerProvider),
  );
});

enum UploadStatus { selected, queued, uploading, uploaded, cancelled, failed }

class UploadItem {
  const UploadItem({
    required this.localId,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.path,
    required this.status,
    required this.progress,
    this.fileId,
    this.uploadJobId,
    this.error,
  });

  final String localId;
  final String name;
  final int size;
  final String mimeType;
  final String path;
  final UploadStatus status;
  final double progress;
  final int? fileId;
  final int? uploadJobId;
  final String? error;

  UploadItem copyWith({
    UploadStatus? status,
    double? progress,
    int? fileId,
    int? uploadJobId,
    String? error,
  }) => UploadItem(
    localId: localId,
    name: name,
    size: size,
    mimeType: mimeType,
    path: path,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    fileId: fileId ?? this.fileId,
    uploadJobId: uploadJobId ?? this.uploadJobId,
    error: error,
  );
}

class UploadController extends ChangeNotifier {
  UploadController(this._api, this._drive);

  static const maxFiles = 50;
  static const pollInterval = Duration(milliseconds: 1200);

  final ApiClient _api;
  final DriveController _drive;
  final _uuid = const Uuid();
  CancelToken? _cancelToken;
  Timer? _pollTimer;
  String? _uploadClientId;

  List<UploadItem> items = [];
  bool picking = false;
  bool uploading = false;
  bool sheetVisible = false;
  int? batchId;
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
  int get activeCount => items
      .where(
        (i) =>
            i.status == UploadStatus.uploading ||
            i.status == UploadStatus.queued,
      )
      .length;

  Future<void> pickFiles({String? folderId}) async {
    if (picking || uploading) return;
    picking = true;
    error = null;
    activeFolderId = folderId;
    notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      if (result.files.length > maxFiles) {
        error = 'Select at most $maxFiles files at once.';
        return;
      }
      items = result.files.where((f) => f.path != null).map((file) {
        final mime =
            lookupMimeType(file.path!, headerBytes: null) ??
            'application/octet-stream';
        return UploadItem(
          localId: _uuid.v4(),
          name: file.name,
          size: file.size,
          mimeType: mime,
          path: file.path!,
          status: UploadStatus.selected,
          progress: 0,
        );
      }).toList();
      sheetVisible = items.isNotEmpty;
      _syncOptimistic();
    } catch (err) {
      error = _api.errorMessage(err, 'Document picking failed.');
    } finally {
      picking = false;
      notifyListeners();
    }
  }

  Future<void> confirmUpload() async {
    final queue = items
        .where(
          (i) =>
              i.status == UploadStatus.selected ||
              i.status == UploadStatus.failed ||
              i.status == UploadStatus.cancelled,
        )
        .toList();
    if (queue.isEmpty) return;
    uploading = true;
    error = null;
    batchId = null;
    _uploadClientId = _uuid.v4();
    _cancelToken = CancelToken();
    items = items
        .map(
          (i) => queue.any((q) => q.localId == i.localId)
              ? i.copyWith(
                  status: UploadStatus.queued,
                  progress: 0,
                  error: null,
                )
              : i,
        )
        .toList();
    _syncOptimistic();
    notifyListeners();
    try {
      final form = FormData();
      for (final item in queue) {
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
      if (activeFolderId != null)
        form.fields.add(MapEntry('folder_id', activeFolderId!));
      form.fields.add(MapEntry('upload_client_id', _uploadClientId!));
      final res = await _api.dio.post(
        '/files/upload',
        data: form,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          final progress = total <= 0 ? 0.05 : (sent / total).clamp(0.0, 0.95);
          items = items
              .map(
                (i) => queue.any((q) => q.localId == i.localId)
                    ? i.copyWith(
                        status: UploadStatus.uploading,
                        progress: progress,
                      )
                    : i,
              )
              .toList();
          _syncOptimistic();
          notifyListeners();
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['status'] == 'cancelled') return;
      batchId = (data['batch_id'] as num).toInt();
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      var index = 0;
      items = items.map((i) {
        if (!queue.any((q) => q.localId == i.localId)) return i;
        final matched = index < files.length ? files[index++] : null;
        if (matched == null) return i.copyWith(status: UploadStatus.queued);
        return i.copyWith(
          status: _toUploadStatus('${matched['status']}'),
          fileId: (matched['file_id'] as num?)?.toInt(),
          uploadJobId: (matched['upload_job_id'] as num?)?.toInt(),
        );
      }).toList();
      notifyListeners();
      _startPolling(batchId!);
      await _pollBatch(batchId!);
    } catch (err) {
      if (err is DioException && CancelToken.isCancel(err)) return;
      final message = _api.errorMessage(err, 'Upload failed.');
      error = message;
      uploading = false;
      items = items
          .map(
            (i) => queue.any((q) => q.localId == i.localId)
                ? i.copyWith(status: UploadStatus.failed, error: message)
                : i,
          )
          .toList();
      _syncOptimistic();
      notifyListeners();
    }
  }

  void _startPolling(int id) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _pollBatch(id));
  }

  Future<void> _pollBatch(int id) async {
    try {
      final res = await _api.dio.get('/upload-batches/$id');
      final data = Map<String, dynamic>.from(res.data as Map);
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      items = items.map((item) {
        final matched = files
            .where((f) => f['upload_job_id'] == item.uploadJobId)
            .firstOrNull;
        if (matched == null) return item;
        final total =
            (matched['total_bytes'] as num?)?.toDouble() ??
            item.size.toDouble();
        final done = (matched['progress_bytes'] as num?)?.toDouble() ?? 0;
        final progress = total > 0
            ? (done / total).clamp(0.0, 1.0)
            : (matched['status'] == 'completed' ? 1.0 : item.progress);
        return item.copyWith(
          status: _toUploadStatus('${matched['status']}'),
          progress: progress,
          fileId: (matched['file_id'] as num?)?.toInt(),
          error: matched['error'] as String?,
        );
      }).toList();
      final status = '${data['status']}';
      if (status == 'completed' ||
          status == 'completed_with_errors' ||
          status == 'cancelled') {
        _pollTimer?.cancel();
        uploading = false;
        await _drive.refresh(silent: true);
      }
      _syncOptimistic();
      notifyListeners();
    } catch (err) {
      error = _api.errorMessage(err, 'Upload polling failed.');
      _pollTimer?.cancel();
      uploading = false;
      notifyListeners();
    }
  }

  Future<void> cancelUpload() async {
    final clientId = _uploadClientId;
    _cancelToken?.cancel('Upload cancelled.');
    _pollTimer?.cancel();
    uploading = false;
    items = items
        .map((i) => i.copyWith(status: UploadStatus.cancelled))
        .toList();
    notifyListeners();
    if (batchId != null) {
      await _api.dio
          .post('/upload-batches/$batchId/cancel')
          .catchError((_) => Response(requestOptions: RequestOptions()));
    } else if (clientId != null) {
      await _api.dio
          .post('/files/upload/cancel', data: {'upload_client_id': clientId})
          .catchError((_) => Response(requestOptions: RequestOptions()));
    }
    await _drive.refresh(silent: true);
  }

  Future<void> retryFailed() async {
    items = items
        .map(
          (i) =>
              i.status == UploadStatus.failed ||
                  i.status == UploadStatus.cancelled
              ? i.copyWith(
                  status: UploadStatus.selected,
                  progress: 0,
                  error: null,
                )
              : i,
        )
        .toList();
    notifyListeners();
    await confirmUpload();
  }

  void dismiss() {
    if (uploading) return;
    items = [];
    sheetVisible = false;
    batchId = null;
    error = null;
    _syncOptimistic();
    notifyListeners();
  }

  UploadStatus _toUploadStatus(String status) {
    if (status == 'completed') return UploadStatus.uploaded;
    if (status == 'cancelled') return UploadStatus.cancelled;
    if (status == 'failed') return UploadStatus.failed;
    if (status == 'uploading' ||
        status == 'processing_original' ||
        status == 'processing_thumbnail' ||
        status == 'uploading_original' ||
        status == 'uploading_thumbnail' ||
        status == 'processing_preview' ||
        status == 'available') {
      return UploadStatus.uploading;
    }
    return UploadStatus.queued;
  }

  void _syncOptimistic() {
    _drive.syncOptimisticUploads(
      items.map((i) {
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
