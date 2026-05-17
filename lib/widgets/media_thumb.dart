import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/storage/thumbnail_cache_manager.dart';
import '../models/drive_models.dart';

class MediaThumb extends StatelessWidget {
  const MediaThumb({
    required this.file,
    this.fit = BoxFit.contain,
    this.radius = 14,
    super.key,
  });

  final DriveFile file;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = file.thumbnailUrl ?? file.previewUrl;
    final bg = Theme.of(context).colorScheme.secondary.withValues(alpha: .55);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: bg,
        child: url == null
            ? _fallback(context)
            : url.startsWith('/') || url.contains(':\\')
            ? Image.file(
                File(url),
                fit: fit,
                cacheWidth: 320,
                cacheHeight: 320,
                errorBuilder: (_, __, ___) => _fallback(context),
              )
            : CachedNetworkImage(
                cacheManager: TeleDriveThumbnailCacheManager.instance,
                imageUrl: url,
                fit: fit,
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

  Widget _fallback(BuildContext context) {
    final icon = switch (file.kind) {
      FileKind.video => Icons.play_circle_outline,
      FileKind.image => Icons.image_outlined,
      FileKind.pdf => Icons.picture_as_pdf_outlined,
      FileKind.audio => Icons.graphic_eq,
      FileKind.zip => Icons.archive_outlined,
      FileKind.doc ||
      FileKind.sheet ||
      FileKind.slides => Icons.description_outlined,
      FileKind.code => Icons.code,
      _ => Icons.insert_drive_file_outlined,
    };
    return Center(
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .45),
      ),
    );
  }
}
