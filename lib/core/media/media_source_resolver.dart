import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/drive_models.dart';
import '../telegram/telegram_client_exceptions.dart';
import '../telegram/telegram_media_access_service.dart';

enum MediaImageUse { thumbnail, fullImage }

class MediaSourceResolver {
  const MediaSourceResolver._();

  static List<String> imageUrls(DriveFile file, MediaImageUse use) {
    return switch (use) {
      MediaImageUse.thumbnail => _dedupe([file.thumbnailUrl, file.previewUrl]),
      MediaImageUse.fullImage => _dedupe([file.previewUrl, file.thumbnailUrl]),
    };
  }

  static List<String> imageTelegramVariants(DriveFile file, MediaImageUse use) {
    final variants = switch (use) {
      MediaImageUse.thumbnail => <String>[
        if (file.thumbnailRefAvailable) 'thumbnail',
        if (file.previewRefAvailable) 'preview',
        if (file.kind == FileKind.image && file.originalRefAvailable)
          'original',
      ],
      MediaImageUse.fullImage => <String>[
        if (file.previewRefAvailable) 'preview',
        if (file.thumbnailRefAvailable) 'thumbnail',
        if (file.kind == FileKind.image && file.originalRefAvailable)
          'original',
      ],
    };
    if (variants.isNotEmpty) return _dedupe(variants);
    if (file.isClientManaged && use == MediaImageUse.fullImage) {
      return const ['original'];
    }
    return const [];
  }

  static List<String> videoUrls(DriveFile file, String? overrideUrl) {
    return _dedupe([overrideUrl, file.streamUrl]);
  }

  static bool canDownloadVideoOriginal(DriveFile file) =>
      file.originalRefAvailable || file.isClientManaged;

  static Future<File?> downloadTelegramVariant(
    WidgetRef ref,
    DriveFile file,
    String variant,
  ) async {
    try {
      return await ref
          .read(telegramMediaAccessServiceProvider)
          .downloadForPrivateView(
            file,
            variant: variant,
            timeout: timeoutForVariant(variant),
          );
    } on TelegramClientException catch (err) {
      _debugFailure(file, variant, err);
      return null;
    } catch (err) {
      _debugFailure(file, variant, err);
      return null;
    }
  }

  static Future<File?> downloadFirstTelegramImage(
    WidgetRef ref,
    DriveFile file,
    MediaImageUse use,
  ) async {
    for (final variant in imageTelegramVariants(file, use)) {
      final local = await downloadTelegramVariant(ref, file, variant);
      if (local != null) return local;
    }
    return null;
  }

  static Duration timeoutForVariant(String variant) {
    return variant == 'original'
        ? const Duration(minutes: 10)
        : const Duration(seconds: 45);
  }

  static bool isLocalPath(String value) =>
      value.startsWith('/') || value.contains(':\\');

  static List<String> _dedupe(Iterable<String?> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) continue;
      out.add(trimmed);
    }
    return out;
  }

  static void _debugFailure(DriveFile file, String variant, Object err) {
    if (!kDebugMode) return;
    debugPrint(
      'Media fallback failed file=${file.id} variant=$variant error=$err',
    );
  }
}
