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

part 'upload_controller/upload_state_sync.dart';
part 'upload_controller/upload_transport.dart';

final uploadControllerProvider = ChangeNotifierProvider<UploadController>((
  ref,
) {
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

  Future<void> _handlePicker(
    Future<UploadPickerResult> Function() pickAction,
    String defaultErrorMessage,
  ) async {
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

    if (item.batchId != null) _stopPollingBatch(item.batchId!);
    _runningLocalIds.remove(localId);
    _setItem(localId, status: UploadStatus.cancelled);
    unawaited(_safeDeleteLocalFile(item.path));
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

  void removeFailed(String localId) {
    final item = _findItem(localId);
    if (item == null) return;
    if (item.status != UploadStatus.failed &&
        item.status != UploadStatus.cancelled) {
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

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
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
