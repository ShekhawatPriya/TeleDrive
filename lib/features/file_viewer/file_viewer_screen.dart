import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import 'components/document_preview.dart';
import 'components/image_preview.dart';
import 'components/metadata_block.dart';
import 'components/video_preview.dart';

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
    final url = file.downloadUrl;
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
      if (url == null && file.storageMode == 'client_managed') {
        final media = await ref
            .read(driveRepositoryProvider)
            .mediaRef(file.id, variant: 'original');
        final telegramRef = media.ref;
        if (telegramRef == null) {
          throw Exception('Telegram media reference is unavailable.');
        }
        final telegram = ref.read(telegramTransferServiceProvider);
        final user = ref.read(authControllerProvider).user;
        if (user == null || user.telegramId == 0) {
          throw Exception('Connect Telegram before opening this file.');
        }
        await telegram.configure(
          backendUserId: '${user.userId}',
          telegramUserId: user.telegramId,
        );
        if (!await telegram.isAuthorized) {
          throw Exception('Local Telegram session is not authorized.');
        }
        final result = await telegram.downloadToCache(
          telegramRef,
          filename: file.name,
          cacheKey: media.cacheKey,
        );
        await OpenFilex.open(result.file.path);
        return;
      }
      if (url == null) return;
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
      content = VideoPreview(url: file.streamUrl!);
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
