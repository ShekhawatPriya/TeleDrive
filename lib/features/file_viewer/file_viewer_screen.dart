import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/storage/thumbnail_cache_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';

class FileViewerScreen extends ConsumerWidget {
  const FileViewerScreen({required this.fileId, super.key});
  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveControllerProvider);
    final file = drive.file(fileId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (file == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'File not found',
          body: 'Refresh Drive and try again.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.6,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _StarButton(file: file),
          IconButton(
            tooltip: 'Download',
            onPressed: () => _download(context, ref, file),
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _PreviewCard(
            file: file,
            onOpen: () => _openExternal(context, ref, file),
          ),
          const SizedBox(height: 24),
          Text(
            file.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            _subtitle(file),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _MetadataBlock(file: file),
        ],
      ),
    );
  }

  String _subtitle(DriveFile file) {
    final parts = <String>[
      formatLabel(file),
      formatFileSize(file.size),
      formatDate(file.modifiedAt),
    ];
    return parts.where((p) => p.isNotEmpty).join('  \u00b7  ');
  }

  Future<void> _download(BuildContext context, WidgetRef ref, DriveFile file) =>
      _openExternal(context, ref, file);

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    DriveFile file,
  ) async {
    final url = file.downloadUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Preparing file...'),
          duration: Duration(seconds: 1),
        ),
      );
      final api = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();
      final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${dir.path}/$safeName';
      if (!await File(path).exists()) {
        await api.dio.download(url, path);
      }
      await OpenFilex.open(path);
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref
                .read(apiClientProvider)
                .errorMessage(err, 'Could not open file.'),
          ),
        ),
      );
    }
  }
}

class _StarButton extends ConsumerWidget {
  const _StarButton({required this.file});
  final DriveFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final starred = file.starred;
    return IconButton(
      tooltip: starred ? 'Remove star' : 'Add star',
      onPressed: () async {
        await HapticFeedback.selectionClick();
        await ref.read(driveControllerProvider).toggleStar(file.id);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          starred ? Icons.star_rounded : Icons.star_outline_rounded,
          key: ValueKey(starred),
          color: starred ? scheme.primary : scheme.onSurface,
          size: 24,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.file, required this.onOpen});

  final DriveFile file;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isVideo = isVideoFile(file) && file.streamUrl != null;
    final isImage = isImageFile(file);

    final Widget content;
    final double aspect;

    if (isVideo) {
      aspect = 16 / 9;
      content = _VideoPlayer(url: file.streamUrl!);
    } else if (isImage) {
      aspect = 4 / 3;
      content = _ImagePreview(file: file);
    } else {
      aspect = 4 / 5;
      content = _DocumentPreview(file: file, onOpen: onOpen);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: AspectRatio(
        aspectRatio: aspect,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: content,
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file});
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

class _DocumentPreview extends StatefulWidget {
  const _DocumentPreview({required this.file, required this.onOpen});
  final DriveFile file;
  final VoidCallback onOpen;

  @override
  State<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<_DocumentPreview> {
  bool _opening = false;

  Future<void> _handleOpen() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      widget.onOpen();
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = _kindLabel(widget.file.kind, widget.file.name);
    final accent = _kindAccent(widget.file.kind, scheme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.78,
                child: CustomPaint(
                  painter: _DocumentPagePainter(
                    fillColor: scheme.surface,
                    borderColor: scheme.outlineVariant,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        const Spacer(),
                        _DocLine(
                          width: double.infinity,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.85,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.7,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.92,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        _DocLine(
                          widthFraction: 0.55,
                          color: scheme.outlineVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _opening ? null : _handleOpen,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadii.pill),
                  ),
                ),
              ),
              icon: _opening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(_actionLabel(widget.file.kind)),
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(FileKind kind) {
    return switch (kind) {
      FileKind.pdf => 'Open PDF',
      FileKind.audio => 'Play audio',
      FileKind.zip => 'Open archive',
      FileKind.doc => 'Open document',
      FileKind.sheet => 'Open spreadsheet',
      FileKind.slides => 'Open slides',
      FileKind.code || FileKind.text => 'Open file',
      _ => 'Open file',
    };
  }

  String _kindLabel(FileKind kind, String name) {
    final ext = extensionOf(name).toUpperCase();
    return switch (kind) {
      FileKind.pdf => 'PDF',
      FileKind.audio => ext.isNotEmpty ? ext : 'AUDIO',
      FileKind.zip => ext.isNotEmpty ? ext : 'ARCHIVE',
      FileKind.doc => ext.isNotEmpty ? ext : 'DOC',
      FileKind.sheet => ext.isNotEmpty ? ext : 'SHEET',
      FileKind.slides => ext.isNotEmpty ? ext : 'SLIDES',
      FileKind.code => ext.isNotEmpty ? ext : 'CODE',
      FileKind.text => ext.isNotEmpty ? ext : 'TEXT',
      _ => ext.isNotEmpty ? ext : 'FILE',
    };
  }

  Color _kindAccent(FileKind kind, ColorScheme scheme) {
    return switch (kind) {
      FileKind.pdf => AppColors.error,
      FileKind.doc => AppColors.link,
      FileKind.sheet => AppColors.green,
      FileKind.slides => AppColors.violet,
      _ => scheme.primary,
    };
  }
}

class _DocLine extends StatelessWidget {
  const _DocLine({this.width, this.widthFraction = 1, required this.color});
  final double? width;
  final double widthFraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFraction,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _DocumentPagePainter extends CustomPainter {
  _DocumentPagePainter({required this.fillColor, required this.borderColor});

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 10.0;
    const fold = 14.0;
    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: const Radius.circular(radius),
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(
        Offset(0, size.height - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    final foldPath = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold);
    final foldFill = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldFill);

    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, stroke);
    canvas.drawLine(
      Offset(size.width - fold, 0),
      Offset(size.width - fold, fold),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - fold, fold),
      Offset(size.width, fold),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DocumentPagePainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}

class _MetadataBlock extends StatelessWidget {
  const _MetadataBlock({required this.file});
  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <_MetaRow>[
      _MetaRow('Type', formatLabel(file)),
      _MetaRow('Size', formatFileSize(file.size)),
      _MetaRow('Modified', formatDate(file.modifiedAt)),
      if (file.createdAt.isNotEmpty && file.createdAt != file.modifiedAt)
        _MetaRow('Created', formatDate(file.createdAt)),
      if (file.mimeType != null && file.mimeType!.isNotEmpty)
        _MetaRow('MIME', file.mimeType!),
      if (file.widthPx != null && file.heightPx != null)
        _MetaRow('Dimensions', '${file.widthPx} × ${file.heightPx}'),
      if (file.duration != null)
        _MetaRow('Duration', formatDuration(file.duration!)),
      _MetaRow('Upload', _humanize(file.uploadStatus ?? 'available')),
      _MetaRow(
        'Preview',
        file.previewStatus == 'available' || file.previewUrl != null
            ? 'Available'
            : 'Unavailable',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i != 0)
                Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        rows[i].label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].value,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _humanize(String status) {
    if (status.isEmpty) return '—';
    if (status.length <= 1) return status.toUpperCase();
    return status[0].toUpperCase() + status.substring(1);
  }
}

class _MetaRow {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.url});
  final String url;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? video;
  ChewieController? chewie;
  Object? error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        video = controller;
        chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
        );
      });
    } catch (err) {
      setState(() => error = err);
    }
  }

  @override
  void dispose() {
    chewie?.dispose();
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return const Center(child: Icon(Icons.video_file_outlined, size: 48));
    }
    final c = chewie;
    if (c == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Chewie(controller: c);
  }
}
