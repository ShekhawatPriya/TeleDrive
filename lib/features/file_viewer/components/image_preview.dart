import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_source_resolver.dart';
import '../../../core/storage/thumbnail_cache_manager.dart';
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
  String? _sourceKey;
  final Set<String> _failedUrls = {};

  Future<File?>? _ensureLocalFuture(DriveFile file) {
    if (file.uploadStatus != null && file.uploadStatus != 'available') {
      return null;
    }
    final variants = MediaSourceResolver.imageTelegramVariants(
      file,
      MediaImageUse.fullImage,
    );
    if (variants.isEmpty) return null;
    final key =
        '${file.id}:${variants.join(',')}:${file.previewVersion ?? 0}:'
        '${file.thumbnailVersion ?? 0}';
    if (_localKey != key) {
      _localKey = key;
      _localFuture = MediaSourceResolver.downloadFirstTelegramImage(
        ref,
        file,
        MediaImageUse.fullImage,
      );
    }
    return _localFuture;
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final scheme = Theme.of(context).colorScheme;
    _resetIfSourceChanged(file);
    final urls = MediaSourceResolver.imageUrls(
      file,
      MediaImageUse.fullImage,
    ).where((url) => !_failedUrls.contains(url)).toList();
    final url = urls.isEmpty ? null : urls.first;

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
    return _buildImage(context, provider, url: url);
  }

  Widget _buildImage(
    BuildContext context,
    ImageProvider provider, {
    String? url,
  }) {
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
            errorBuilder: (_, err, _) {
              if (url != null) return _urlError(scheme, url, err);
              _debug('Local image decode failed', err);
              return _placeholder(scheme);
            },
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

  Widget _urlError(ColorScheme scheme, String url, Object err) {
    _debug('Image URL failed: $url', err);
    if (_failedUrls.add(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return _placeholder(scheme);
  }

  void _resetIfSourceChanged(DriveFile file) {
    final nextKey =
        '${file.id}|${file.previewUrl}|${file.thumbnailUrl}|'
        '${file.previewRefAvailable}|${file.thumbnailRefAvailable}|'
        '${file.originalRefAvailable}|${file.previewVersion}|'
        '${file.thumbnailVersion}|${file.uploadStatus}';
    if (_sourceKey == nextKey) return;
    _sourceKey = nextKey;
    _failedUrls.clear();
    _localFuture = null;
    _localKey = null;
  }

  void _debug(String message, Object err) {
    if (!kDebugMode) return;
    debugPrint('$message: $err');
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
