import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/telegram/telegram_client_exceptions.dart';
import '../../models/drive_models.dart';
import 'file_copy_share_service.dart';

class CopyShareController extends ChangeNotifier {
  CopyShareController(this.service, this.files);
  final FileCopyShareService service;
  final List<DriveFile> files;
  CancelToken? _cancellation;
  bool _disposed = false;
  bool cancelled = false;
  bool busy = false;
  String? error;
  List<XFile>? result;
  CopyPreparationProgress? progress;
  Timer? _notificationTimer;

  Future<void> start() async {
    if (busy || _disposed) return;
    final cancellation = _cancellation = CancelToken();
    cancelled = false;
    busy = true;
    error = null;
    result = null;
    progress = null;
    notifyListeners();
    try {
      final copies = await service.prepare(
        files,
        cancellation: cancellation,
        onProgress: (value) {
          if (_disposed || cancellation.isCancelled) return;
          final changedFile =
              progress?.index != value.index ||
              progress?.preparingCopy != value.preparingCopy;
          progress = value;
          // Native transfer events can arrive faster than display frames.
          if (changedFile || value.received == value.total) {
            _notificationTimer?.cancel();
            _notificationTimer = null;
            notifyListeners();
          } else {
            _notificationTimer ??= Timer(const Duration(milliseconds: 100), () {
              _notificationTimer = null;
              if (!_disposed && !cancelled) notifyListeners();
            });
          }
        },
      );
      if (!_disposed && !cancellation.isCancelled) result = copies;
    } catch (failure) {
      if (cancellation.isCancelled ||
          (failure is DioException && CancelToken.isCancel(failure))) {
        cancelled = true;
      } else if (failure is TelegramClientUnavailableException ||
          failure is TelegramAccountMismatchException) {
        error =
            'Connect the matching Telegram account in Settings, then try again.';
      } else {
        error =
            'Could not download the original. Check your connection and try again.';
      }
    } finally {
      _notificationTimer?.cancel();
      _notificationTimer = null;
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void cancel() {
    cancelled = true;
    _notificationTimer?.cancel();
    _notificationTimer = null;
    if (!(_cancellation?.isCancelled ?? true))
      _cancellation!.cancel('Share cancelled');
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _notificationTimer?.cancel();
    if (!(_cancellation?.isCancelled ?? true))
      _cancellation!.cancel('Share closed');
    super.dispose();
  }
}
