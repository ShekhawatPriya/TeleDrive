import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/storage/thumbnail_cache_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../../../models/drive_models.dart';
import '../../upload_models.dart';

/// Leading thumb slot in an upload card.
///
///   active upload -> bounded local photo when available, otherwise a file glyph
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
    final localImage =
        detectFileKind(item.name, item.mimeType) == FileKind.image &&
        item.path.startsWith('/');
    final showSpinner =
        _isUploaded && _isPreviewable && !item.thumbnailReady && !localImage;
    final showThumb =
        (_isUploaded && _isPreviewable && item.thumbnailReady) || localImage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        width: size,
        height: size,
        color: bg,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.short4,
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
    final theme = Theme.of(context);
    return Center(
      child: Icon(
        _iconFor(kind, theme.platform == TargetPlatform.iOS),
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.kind, super.key});
  final FileKind kind;

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primary;
    if (MediaQuery.disableAnimationsOf(context)) return _Glyph(kind: kind);
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
    final url =
        item.thumbnailUrl ??
        (detectFileKind(item.name, item.mimeType) == FileKind.image &&
                item.path.startsWith('/')
            ? item.path
            : null);
    if (url == null || url.isEmpty)
      return _Glyph(kind: detectFileKind(item.name, item.mimeType));
    final isLocal = url.startsWith('/') || url.contains(':\\');
    if (isLocal) {
      return Image.file(
        File(url),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorBuilder: (_, __, ___) =>
            _Glyph(kind: detectFileKind(item.name, item.mimeType)),
      );
    }
    return CachedNetworkImage(
      cacheManager: TeleDriveThumbnailCacheManager.instance,
      fadeInDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.short4,
      fadeOutDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.short4,
      imageUrl: url,
      width: double.infinity,
      height: double.infinity,
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

IconData _iconFor(FileKind kind, bool ios) {
  if (ios) {
    return switch (kind) {
      FileKind.image => CupertinoIcons.photo,
      FileKind.video => CupertinoIcons.play_rectangle,
      FileKind.audio => CupertinoIcons.music_note_2,
      FileKind.zip => CupertinoIcons.archivebox,
      FileKind.code => CupertinoIcons.chevron_left_slash_chevron_right,
      _ => CupertinoIcons.doc_text,
    };
  }
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
