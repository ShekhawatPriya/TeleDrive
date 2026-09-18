import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/drive/drive_controller.dart';
import '../../features/drive/drive_repository.dart';
import '../../features/auth/auth_controller.dart';
import '../../models/drive_models.dart';
import '../config/app_config.dart';
import 'telegram_client_exceptions.dart';
import 'telegram_transfer_service.dart';

final telegramMediaAccessServiceProvider = Provider<TelegramMediaAccessService>(
  (ref) {
    final service = TelegramMediaAccessService(
      driveRepository: ref.watch(driveRepositoryProvider),
      transferService: ref.watch(telegramTransferServiceProvider),
      auth: ref.watch(authControllerProvider.notifier),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

class TelegramMediaAccessService {
  TelegramMediaAccessService({
    required this._driveRepository,
    required this._transferService,
    required this._auth,
  }) {
    _identity = _currentIdentity;
    _auth.addListener(_authChanged);
  }

  final DriveRepository _driveRepository;
  final TelegramTransferService _transferService;
  final AuthController _auth;
  Object? _identity;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _configuration;
  Future<void> _configurationTail = Future<void>.value();

  int? get _backendUserId => _auth.user?.userId ?? _auth.activeAccount?.userId;
  int? get _telegramUserId {
    final id = _auth.user?.telegramId;
    return id != null && id != 0 ? id : _auth.activeAccount?.telegramId;
  }

  Object get _currentIdentity =>
      (_backendUserId, _telegramUserId, _auth.token, _auth.switchingAccount);

  void _authChanged() {
    final identity = _currentIdentity;
    if (_identity == identity) return;
    _identity = identity;
    _generation++;
    _configuration = null;
  }

  void _check(int generation, CancelToken? token) {
    if (token?.isCancelled ?? false) throw token!.cancelError!;
    if (_disposed || generation != _generation || _auth.switchingAccount) {
      throw const TelegramClientUnavailableException(
        'The active account changed. Open the file again.',
        code: 'media_account_changed',
      );
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _auth.removeListener(_authChanged);
  }

  Future<File?> downloadForPrivateView(
    DriveFile file, {
    String variant = 'original',
    Duration? timeout,
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    if (file.uploadStatus != null && file.uploadStatus != 'available') {
      return null;
    }
    final generation = _generation;
    _check(generation, cancelToken);
    var configuration = _configuration;
    if (configuration == null) {
      configuration = _configurationTail.then((_) {
        _check(generation, null);
        return _configureForActiveUser(generation);
      });
      // Serialize native scope changes even if an older account is still
      // awaiting secure storage or local database initialization.
      _configurationTail = configuration.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
      _configuration = configuration;
      unawaited(
        configuration.then<void>(
          (_) {
            if (identical(_configuration, configuration)) _configuration = null;
          },
          onError: (Object _, StackTrace __) {
            if (identical(_configuration, configuration)) _configuration = null;
          },
        ),
      );
    }
    if (cancelToken == null) {
      await configuration;
    } else {
      await Future.any([
        configuration,
        cancelToken.whenCancel.then<void>((error) => throw error),
      ]).timeout(const Duration(seconds: 15));
    }
    _check(generation, cancelToken);
    final ref = await _driveRepository.mediaRef(
      file.id,
      variant: variant,
      cancelToken: cancelToken,
    );
    _check(generation, cancelToken);
    final telegramRef = ref.ref;
    if (telegramRef == null) {
      throw const TelegramClientUnavailableException(
        'No Telegram media reference is available for this file.',
        code: 'media_ref_missing',
      );
    }
    final result = await _transferService.downloadToCache(
      telegramRef,
      filename: file.name,
      cacheKey:
          '${AppConfig.storageNamespace}:$_backendUserId:$_telegramUserId:${ref.cacheKey}:${file.modifiedAt}:${file.size}:${file.thumbnailVersion}:${file.previewVersion}',
      timeout: timeout,
      variant: variant,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    _check(generation, cancelToken);
    return result.file;
  }

  Future<void> _configureForActiveUser(int generation) async {
    final backendUserId = _backendUserId;
    final telegramUserId = _telegramUserId;
    if (backendUserId == null ||
        telegramUserId == null ||
        telegramUserId == 0) {
      throw const TelegramClientUnavailableException(
        'Connect Telegram before opening this file.',
        code: 'tdlib_not_connected',
      );
    }
    await _transferService.configure(
      backendUserId: '$backendUserId',
      telegramUserId: telegramUserId,
    );
    _check(generation, null);
    final authorized = await _transferService.isAuthorized;
    _check(generation, null);
    if (!authorized) {
      throw const TelegramClientUnavailableException(
        'Local TDLib session is not authorized.',
        code: 'tdlib_auth_required',
      );
    }
    final me = await _transferService.getMe();
    _check(generation, null);
    final actualTelegramId = _intish(me['telegramUserId'] ?? me['id']);
    if (actualTelegramId != telegramUserId) {
      throw const TelegramAccountMismatchException(
        'Local TDLib account does not match the active TeleDrive account.',
        code: 'tdlib_account_mismatch',
      );
    }
  }
}

int? _intish(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
