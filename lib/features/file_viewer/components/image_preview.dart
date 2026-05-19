import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/thumbnail_cache_manager.dart';
import '../../../models/drive_models.dart';

class ImagePreview extends StatelessWidget {
  const ImagePreview({required this.file, super.key});
  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    final url = file.previewUrl ?? file.thumbnailUrl;
    final scheme = Theme.of(context).colorScheme;
    if (url == null) {
      return Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: scheme.onSurface.withValues(alpha: 0.45),
        ),
      );
    }
    final isLocal = url.startsWith('/') || url.contains(':\\');
    final ImageProvider provider = isLocal
        ? FileImage(File(url))
        : CachedNetworkImageProvider(
            url,
            cacheManager: TeleDriveThumbnailCacheManager.instance,
          );
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
            errorBuilder: (_, __, ___) => Icon(
              Icons.image_outlined,
              size: 48,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
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
}
