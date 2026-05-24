import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/thumbnail_cache_manager.dart';
import '../core/telegram/telegram_client_exceptions.dart';
import '../core/telegram/telegram_transfer_service.dart';
import '../features/drive/drive_controller.dart';
import '../models/drive_models.dart';
import 'google_drive_icon.dart';

class MediaThumb extends ConsumerStatefulWidget {
  const MediaThumb({
    required this.file,
    this.fit = BoxFit.contain,
    this.radius = 18,
    this.showBackground = true,
    super.key,
  });

  final DriveFile file;
  final BoxFit fit;
  final double radius;
  final bool showBackground;

  @override
  ConsumerState<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends ConsumerState<MediaThumb> {
  Future<File?>? _clientThumbFuture;
  String? _clientThumbKey;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final url = file.thumbnailUrl ?? file.previewUrl;
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (url == null) {
      final clientThumb = _clientThumbnailFuture(file);
      if (clientThumb != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: ColoredBox(
            color: bg,
            child: FutureBuilder<File?>(
              future: clientThumb,
              builder: (context, snapshot) {
                final localFile = snapshot.data;
                if (localFile != null) {
                  return Image.file(
                    localFile,
                    fit: widget.fit,
                    cacheWidth: 320,
                    cacheHeight: 320,
                    errorBuilder: (_, __, ___) => _fallback(context),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _fallback(context);
              },
            ),
          ),
        );
      }
      final fallbackWidget = _fallback(context);
      if (widget.showBackground) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: ColoredBox(color: bg, child: fallbackWidget),
        );
      } else {
        return fallbackWidget;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: ColoredBox(
        color: bg,
        child: url.startsWith('/') || url.contains(':\\')
            ? Image.file(
                File(url),
                fit: widget.fit,
                cacheWidth: 320,
                cacheHeight: 320,
                errorBuilder: (_, __, ___) => _fallback(context),
              )
            : CachedNetworkImage(
                cacheManager: TeleDriveThumbnailCacheManager.instance,
                imageUrl: url,
                fit: widget.fit,
                memCacheWidth: 320,
                memCacheHeight: 320,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => _fallback(context),
              ),
      ),
    );
  }

  Future<File?>? _clientThumbnailFuture(DriveFile file) {
    if (file.storageMode != 'client_managed' ||
        file.uploadStatus != 'available') {
      return null;
    }
    final variant = file.thumbnailRefAvailable
        ? 'thumbnail'
        : file.previewRefAvailable
        ? 'preview'
        : null;
    if (variant == null) return null;
    final version = variant == 'thumbnail'
        ? file.thumbnailVersion
        : file.previewVersion;
    final key = '${file.id}:$variant:${version ?? 0}';
    if (_clientThumbKey != key) {
      _clientThumbKey = key;
      _clientThumbFuture = _downloadClientThumbnail(file, variant);
    }
    return _clientThumbFuture;
  }

  Future<File?> _downloadClientThumbnail(DriveFile file, String variant) async {
    try {
      final mediaRef = await ref
          .read(driveRepositoryProvider)
          .mediaRef(file.id, variant: variant);
      final telegramRef = mediaRef.ref;
      if (telegramRef == null) return null;
      final result = await ref
          .read(telegramTransferServiceProvider)
          .downloadToCache(
            telegramRef,
            filename: file.name,
            cacheKey: mediaRef.cacheKey,
          );
      return result.file;
    } on TelegramClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _fallback(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minDim = math.min(constraints.maxWidth, constraints.maxHeight);
        final iconSize = (minDim.isInfinite || minDim <= 0) ? 40.0 : minDim;
        final targetSize = math.min(iconSize * 0.84, 48.0);
        return Center(
          child: Padding(
            padding: EdgeInsets.all(iconSize * 0.08),
            child: GoogleDriveIcon.file(widget.file, size: targetSize),
          ),
        );
      },
    );
  }
}
