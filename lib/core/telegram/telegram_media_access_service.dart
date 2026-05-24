import 'dart:io';

import '../../features/drive/drive_repository.dart';
import '../../models/drive_models.dart';
import 'telegram_client_exceptions.dart';
import 'telegram_transfer_service.dart';

class TelegramMediaAccessService {
  const TelegramMediaAccessService({
    required DriveRepository driveRepository,
    required TelegramTransferService transferService,
  }) : _driveRepository = driveRepository,
       _transferService = transferService;

  final DriveRepository _driveRepository;
  final TelegramTransferService _transferService;

  Future<File?> downloadForPrivateView(
    DriveFile file, {
    String variant = 'original',
  }) async {
    if (file.storageMode != 'client_managed') return null;
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
    );
    return result.file;
  }
}
