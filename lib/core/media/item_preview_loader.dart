import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/drive_models.dart';
import '../telegram/telegram_media_access_service.dart';
import 'media_source_resolver.dart';
import 'thumbnail_loader.dart';
import 'thumbnail_scheduler.dart';

final itemPreviewLoaderProvider = Provider<ItemPreviewLoader>(
  (ref) => ItemPreviewLoader(
    thumbnails: ref.watch(thumbnailLoaderProvider),
    scheduler: ref.watch(thumbnailSchedulerProvider),
    document: (file, token) => ref
        .read(telegramMediaAccessServiceProvider)
        .downloadForPrivateView(
          file,
          timeout: const Duration(seconds: 15),
          cancelToken: token,
        ),
  ),
);

/// One user-requested preview shares the bounded thumbnail scheduler/cache.
/// Documents are fetched only on hold, with a size/time limit and cancellation.
/// UIKit renders the returned local document using Quick Look; it never fetches
/// URLs, credentials or Telegram references itself.
class ItemPreviewLoader {
  ItemPreviewLoader({
    required this.thumbnails,
    required this.scheduler,
    required this.document,
  });
  final ThumbnailLoader thumbnails;
  final ThumbnailScheduler<File> scheduler;
  final Future<File?> Function(DriveFile, CancelToken) document;

  Future<Map<String, String>?> load(DriveFile file, CancelToken token) async {
    try {
      final urls = MediaSourceResolver.imageUrls(file, MediaImageUse.thumbnail);
      if (urls.isNotEmpty && MediaSourceResolver.isLocalPath(urls.first)) {
        if (await File(urls.first).exists() && !token.isCancelled) {
          return {'imagePath': urls.first};
        }
      }
      if (thumbnails.hasSources(file)) {
        for (final original in [
          false,
          if (thumbnails.canUseOriginal(file)) true,
        ]) {
          if (token.isCancelled) return null;
          final request = scheduler.request(
            '${identityHashCode(thumbnails)}:${thumbnails.keyFor(file)}:$original',
            priority: ThumbnailPriority.visible,
            original: original,
            load: (cancel) => thumbnails.load(file, cancel, original: original),
          );
          token.whenCancel.then((_) => request.release());
          try {
            final local = await Future.any([
              request.future,
              token.whenCancel.then<File?>((_) => null),
            ]);
            if (token.isCancelled) return null;
            if (local != null) return {'imagePath': local.path};
          } finally {
            request.release();
          }
        }
      }
      // Quick Look supports PDF and common office documents. Large/unsupported
      // originals keep the honest file identity card and the existing Open action.
      if ({
            FileKind.pdf,
            FileKind.doc,
            FileKind.sheet,
            FileKind.slides,
            FileKind.text,
          }.contains(file.kind) &&
          file.size > 0 &&
          file.size <= 20 * 1024 * 1024 &&
          !token.isCancelled) {
        final local = await document(file, token);
        if (local != null && !token.isCancelled)
          return {'documentPath': local.path};
      }
    } catch (_) {
      /* Missing/offline/cancelled content retains the identity card. */
    }
    return null;
  }
}
