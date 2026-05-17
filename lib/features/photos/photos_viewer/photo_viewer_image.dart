import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/storage/thumbnail_cache_manager.dart';
import '../../../models/drive_models.dart';

class PhotoViewerImage extends StatelessWidget {
  const PhotoViewerImage({
    required this.file,
    required this.onTap,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = file.previewUrl ?? file.thumbnailUrl;
    if (url == null) return _fallback(context);

    final imageProvider = url.startsWith('/') || url.contains(':\\')
        ? FileImage(File(url)) as ImageProvider
        : CachedNetworkImageProvider(
            url,
            cacheManager: TeleDriveThumbnailCacheManager.instance,
          );

    return PhotoView(
      imageProvider: imageProvider,
      heroAttributes: PhotoViewHeroAttributes(tag: 'photo-${file.id}'),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      onTapUp: (_, __, ___) => onTap(),
      loadingBuilder: (_, __) => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
      errorBuilder: (_, __, ___) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.white54, size: 64),
      ),
    );
  }
}
