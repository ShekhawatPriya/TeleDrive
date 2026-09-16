import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeletons.dart';
import '../drive/drive_controller.dart';
import 'file_open_action.dart';
import 'components/document_preview.dart';
import 'components/image_preview.dart';
import 'components/metadata_block.dart';
import 'components/video_preview.dart';

class FileViewerScreen extends ConsumerStatefulWidget {
  const FileViewerScreen({required this.fileId, super.key});
  final String fileId;

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  // True while we're awaiting `/files/{id}` because the file wasn't yet in
  // any loaded folder page (Starred / Search / deep link path).
  bool _resolving = false;
  bool _opening = false;
  // True only after a server fetch returned no row \u2014 distinguishes "not yet
  // loaded" from "actually missing." We never set this just because the
  // initial sync lookup missed.
  bool _serverSaysMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final drive = ref.read(driveControllerProvider);
      if (drive.anyFile(widget.fileId) != null) return;
      setState(() => _resolving = true);
      drive.ensureFileLoaded(widget.fileId).then((file) {
        if (!mounted) return;
        setState(() {
          _resolving = false;
          _serverSaysMissing = file == null;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final file = drive.anyFile(widget.fileId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (file == null) {
      if (_resolving) {
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0.6,
            elevation: 0,
            titleSpacing: 0,
            title: const Text('Loading\u2026'),
          ),
          body: const SkeletonList(),
        );
      }
      // Sync miss without an in-flight resolve happens only when an earlier
      // resolve already returned null; surface the existing not-found UI.
      if (_serverSaysMissing) {
        return Scaffold(
          appBar: AppBar(title: const Text('File unavailable')),
          body: const EmptyState(
            icon: Icons.error_outline,
            title: 'Could not open this file',
            body: 'Check your connection, then return to Drive and try again.',
          ),
        );
      }
      // Initial frame before the post-frame resolve kicks in.
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(backgroundColor: scheme.surface),
        body: const SkeletonList(),
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
            onPressed: _opening ? null : () => _download(context, ref, file),
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
          MetadataBlock(file: file),
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
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openDriveFileExternally(
        context,
        ref,
        file,
        returnTo: '/file/${file.id}',
      );
    } finally {
      if (mounted) setState(() => _opening = false);
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
    final isVideo = isVideoFile(file);
    final isImage = isImageFile(file);

    final Widget content;
    final double aspect;

    if (isVideo) {
      aspect = 16 / 9;
      content = VideoPreview(file: file);
    } else if (isImage) {
      aspect = 4 / 3;
      content = ImagePreview(file: file);
    } else {
      aspect = 4 / 5;
      content = DocumentPreview(file: file, onOpen: onOpen);
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
