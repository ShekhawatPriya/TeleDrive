import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/drive/drive_controller.dart';
import '../../features/drive/drive_repository.dart';
import '../../features/auth/auth_controller.dart';
import '../../models/drive_models.dart';
import 'telegram_client_exceptions.dart';
import 'telegram_transfer_service.dart';

final telegramMediaAccessServiceProvider = Provider<TelegramMediaAccessService>(
  (ref) => TelegramMediaAccessService(
    driveRepository: ref.watch(driveRepositoryProvider),
    transferService: ref.watch(telegramTransferServiceProvider),
    auth: ref.watch(authControllerProvider),
  ),
);

class TelegramMediaAccessService {
  const TelegramMediaAccessService({
    required this._driveRepository,
    required this._transferService,
    required this._auth,
  });

  final DriveRepository _driveRepository;
  final TelegramTransferService _transferService;
  final AuthController _auth;

  Future<File?> downloadForPrivateView(
    DriveFile file, {
    String variant = 'original',
    Duration? timeout,
  }) async {
    if (file.uploadStatus != null && file.uploadStatus != 'available') {
      return null;
    }
    await _configureForActiveUser();
    final ref = await _driveRepository.mediaRef(file.id, variant: variant);
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
      cacheKey: ref.cacheKey,
      timeout: timeout,
      variant: variant,
    );
    return result.file;
  }

  Future<void> _configureForActiveUser() async {
    final user = _auth.user;
    final account = _auth.activeAccount;
    final backendUserId = user?.userId ?? account?.userId;
    final userTelegramId = user?.telegramId;
    final telegramUserId = userTelegramId != null && userTelegramId != 0
        ? userTelegramId
        : account?.telegramId;
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
    if (!await _transferService.isAuthorized) {
      throw const TelegramClientUnavailableException(
        'Local TDLib session is not authorized.',
        code: 'tdlib_auth_required',
      );
    }
    final me = await _transferService.getMe();
    final actualTelegramId = _intish(me['telegramUserId'] ?? me['id']);
    if (actualTelegramId != null && actualTelegramId != telegramUserId) {
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
