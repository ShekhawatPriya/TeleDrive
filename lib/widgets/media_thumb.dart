import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/media_source_resolver.dart';
import '../core/storage/thumbnail_cache_manager.dart';
import '../models/drive_models.dart';
import 'google_drive_icon.dart';

class MediaThumb extends ConsumerStatefulWidget {
  const MediaThumb({
    required this.file,
    this.fit = BoxFit.contain,
    this.radius = 18,
    this.showBackground = true,
    this.decodeWidth = 320,
    super.key,
  });

  final DriveFile file;
  final BoxFit fit;
  final double radius;
  final bool showBackground;
  final int decodeWidth;

  @override
  ConsumerState<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends ConsumerState<MediaThumb> {
  Future<File?>? _clientThumbFuture;
  String? _clientThumbKey;
  String? _sourceKey;
  final Set<String> _failedUrls = {};

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    _resetIfSourceChanged(file);
    final urls = MediaSourceResolver.imageUrls(
      file,
      MediaImageUse.thumbnail,
    ).where((url) => !_failedUrls.contains(url)).toList();
    final url = urls.isEmpty ? null : urls.first;
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
                    cacheWidth: widget.decodeWidth,

                    errorBuilder: (_, err, _) {
                      _debug('Local thumbnail decode failed', err);
                      return _fallback(context);
                    },
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
                cacheWidth: widget.decodeWidth,

                errorBuilder: (_, err, _) => _urlError(context, url, err),
              )
            : CachedNetworkImage(
                cacheManager: TeleDriveThumbnailCacheManager.instance,
                imageUrl: url,
                fit: widget.fit,
                memCacheWidth: widget.decodeWidth,

                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, err) => _urlError(context, url, err),
              ),
      ),
    );
  }

  Future<File?>? _clientThumbnailFuture(DriveFile file) {
    if (file.uploadStatus != null && file.uploadStatus != 'available') {
      return null;
    }
    final variants = MediaSourceResolver.imageTelegramVariants(
      file,
      MediaImageUse.thumbnail,
    );
    if (variants.isEmpty) return null;
    final key =
        '${file.id}:${variants.join(',')}:${file.thumbnailVersion ?? 0}:'
        '${file.previewVersion ?? 0}';
    if (_clientThumbKey != key) {
      _clientThumbKey = key;
      _clientThumbFuture = MediaSourceResolver.downloadFirstTelegramImage(
        ref,
        file,
        MediaImageUse.thumbnail,
      );
    }
    return _clientThumbFuture;
  }

  Widget _urlError(BuildContext context, String url, Object err) {
    _debug('Thumbnail URL failed: $url', err);
    if (_failedUrls.add(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return _fallback(context);
  }

  void _resetIfSourceChanged(DriveFile file) {
    final nextKey =
        '${file.id}|${file.thumbnailUrl}|${file.previewUrl}|'
        '${file.thumbnailRefAvailable}|${file.previewRefAvailable}|'
        '${file.originalRefAvailable}|${file.thumbnailVersion}|'
        '${file.previewVersion}|${file.uploadStatus}';
    if (_sourceKey == nextKey) return;
    _sourceKey = nextKey;
    _failedUrls.clear();
    _clientThumbFuture = null;
    _clientThumbKey = null;
  }

  void _debug(String message, Object err) {
    if (!kDebugMode) return;
    debugPrint('$message: $err');
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
