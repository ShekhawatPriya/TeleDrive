import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/storage/thumbnail_cache_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../../../models/drive_models.dart';
import '../../upload_models.dart';

/// Leading thumb slot in an upload card.
///
///   active upload -> subtle file-type glyph on a muted surface
///   uploaded, no thumb yet -> spinner over the glyph
///   uploaded + thumb ready -> image fades in
class UploadThumbSlot extends StatelessWidget {
  const UploadThumbSlot({required this.item, this.size = 44, super.key});

  final UploadItem item;
  final double size;

  bool get _isPreviewable {
    final kind = detectFileKind(item.name, item.mimeType);
    return kind == FileKind.image || kind == FileKind.video;
  }

  bool get _isUploaded => item.status == UploadStatus.uploaded;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final showSpinner = _isUploaded && _isPreviewable && !item.thumbnailReady;
    final showThumb = _isUploaded && _isPreviewable && item.thumbnailReady;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: size,
        height: size,
        color: bg,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          child: showThumb
              ? _Thumb(item: item, key: ValueKey('thumb-${item.localId}'))
              : showSpinner
              ? _Spinner(
                  kind: detectFileKind(item.name, item.mimeType),
                  key: ValueKey('spin-${item.localId}'),
                )
              : _Glyph(
                  kind: detectFileKind(item.name, item.mimeType),
                  key: ValueKey('glyph-${item.localId}'),
                ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.kind, super.key});
  final FileKind kind;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: .4);
    return Center(child: Icon(_iconFor(kind), size: 20, color: color));
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.kind, super.key});
  final FileKind kind;

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: .35, child: _Glyph(kind: kind)),
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(
              tint.withValues(alpha: .7),
            ),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, super.key});
  final UploadItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.thumbnailUrl;
    if (url == null)
      return _Glyph(kind: detectFileKind(item.name, item.mimeType));
    final isLocal = url.startsWith('/') || url.contains(':\\');
    if (isLocal) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) =>
            _Glyph(kind: detectFileKind(item.name, item.mimeType)),
      );
    }
    return CachedNetworkImage(
      cacheManager: TeleDriveThumbnailCacheManager.instance,
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 160,
      memCacheHeight: 160,
      placeholder: (_, __) =>
          _Spinner(kind: detectFileKind(item.name, item.mimeType)),
      errorWidget: (_, __, ___) =>
          _Glyph(kind: detectFileKind(item.name, item.mimeType)),
    );
  }
}

IconData _iconFor(FileKind kind) {
  return switch (kind) {
    FileKind.image => Icons.image_outlined,
    FileKind.video => Icons.play_circle_outline,
    FileKind.pdf => Icons.picture_as_pdf_outlined,
    FileKind.audio => Icons.graphic_eq,
    FileKind.zip => Icons.archive_outlined,
    FileKind.doc ||
    FileKind.sheet ||
    FileKind.slides => Icons.description_outlined,
    FileKind.code => Icons.code,
    _ => Icons.insert_drive_file_outlined,
  };
}
