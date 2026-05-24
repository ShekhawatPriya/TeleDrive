import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/thumbnail_cache_manager.dart';
import '../../../core/telegram/telegram_client_exceptions.dart';
import '../../../core/telegram/telegram_media_access_service.dart';
import '../../../models/drive_models.dart';

class ImagePreview extends ConsumerStatefulWidget {
  const ImagePreview({required this.file, super.key});
  final DriveFile file;

  @override
  ConsumerState<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends ConsumerState<ImagePreview> {
  Future<File?>? _localFuture;
  String? _localKey;

  Future<File?>? _ensureLocalFuture(DriveFile file) {
    if (file.storageMode != 'client_managed' ||
        file.uploadStatus != 'available') {
      return null;
    }
    final variant = file.previewRefAvailable
        ? 'preview'
        : file.originalRefAvailable
        ? 'original'
        : null;
    if (variant == null) return null;
    final version = variant == 'preview'
        ? file.previewVersion
        : 0;
    final key = '${file.id}:$variant:${version ?? 0}';
    if (_localKey != key) {
      _localKey = key;
      _localFuture = _downloadLocal(file, variant);
    }
    return _localFuture;
  }

  Future<File?> _downloadLocal(DriveFile file, String variant) async {
    try {
      return await ref
          .read(telegramMediaAccessServiceProvider)
          .downloadForPrivateView(file, variant: variant)
          .timeout(const Duration(seconds: 90));
    } on TelegramClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final scheme = Theme.of(context).colorScheme;
    final url = file.previewUrl ?? file.thumbnailUrl;

    if (url == null) {
      final localFuture = _ensureLocalFuture(file);
      if (localFuture != null) {
        return FutureBuilder<File?>(
          future: localFuture,
          builder: (context, snapshot) {
            final local = snapshot.data;
            if (local != null) {
              return _buildImage(context, FileImage(local));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return _placeholder(scheme);
          },
        );
      }
      return _placeholder(scheme);
    }

    final isLocal = url.startsWith('/') || url.contains(':\\');
    final ImageProvider provider = isLocal
        ? FileImage(File(url))
        : CachedNetworkImageProvider(
            url,
            cacheManager: TeleDriveThumbnailCacheManager.instance,
          );
    return _buildImage(context, provider);
  }

  Widget _buildImage(BuildContext context, ImageProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Image(
            image: provider,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.18)),
        Center(
          child: Image(
            image: provider,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _placeholder(scheme),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: scheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}
