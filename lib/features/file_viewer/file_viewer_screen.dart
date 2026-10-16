import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import '../../widgets/file_name_text.dart';
import '../../widgets/ios/ios_browse.dart';
import '../../widgets/ios_more_menu.dart';
import '../../widgets/item_status.dart';
import '../../widgets/media_thumb.dart';
import '../auth/auth_controller.dart';
import '../drive/components/drive_item_actions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios/ios_page.dart';
import '../../widgets/native_glass_button.dart';
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
    final ios = theme.platform == TargetPlatform.iOS;
    PreferredSizeWidget iosBar(String? title, {Widget? trailing}) =>
        IosNavigationBar.preferred(
          title: title,
          leading: IosNavigationBar.backButton(context),
          trailing: trailing,
        );

    if (file == null) {
      if (_resolving) {
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: ios
              ? iosBar('Loading\u2026')
              : AppBar(
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
          appBar: ios
              ? iosBar('File Unavailable')
              : AppBar(title: const Text('File unavailable')),
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
        appBar: ios ? iosBar(null) : AppBar(backgroundColor: scheme.surface),
        body: const SkeletonList(),
      );
    }
    if (ios) {
      return _IosFileDetail(
        file: file,
        opening: _opening,
        onOpen: () => _openExternal(context, ref, file),
      );
    }
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ios
          ? iosBar(
              file.name,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NativeGlassButton(
                    label: file.starred ? 'Remove star' : 'Add star',
                    symbol: file.starred ? 'star.fill' : 'star',
                    icon: file.starred
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    size: 44,
                    symbolSize: 17,
                    onPressed: () async {
                      await HapticFeedback.selectionClick();
                      await ref
                          .read(driveControllerProvider)
                          .toggleStar(file.id);
                    },
                  ),
                  const SizedBox(width: 8),
                  NativeGlassButton(
                    label: 'Download',
                    symbol: 'arrow.down.circle',
                    icon: CupertinoIcons.arrow_down_circle,
                    size: 44,
                    symbolSize: 17,
                    onPressed: _opening
                        ? null
                        : () => _download(context, ref, file),
                  ),
                ],
              ),
            )
          : AppBar(
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
                  onPressed: _opening
                      ? null
                      : () => _download(context, ref, file),
                  icon: const Icon(Icons.file_download_outlined),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
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
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
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

/// Quick Look-style document page: a centered preview, the name with its
/// status and kind, one Open action (Quick Look or Open In on this iPhone),
/// and grouped information. Every other action lives in the native ⋯ menu,
/// the same menu the item shows elsewhere. Photos and videos open in the full
/// screen viewer instead (see `openDriveFile`).
class _IosFileDetail extends ConsumerWidget {
  const _IosFileDetail({
    required this.file,
    required this.opening,
    required this.onOpen,
  });

  final DriveFile file;
  final bool opening;
  final VoidCallback onOpen;

  static String kindName(DriveFile file) {
    final label = formatLabel(file);
    final noun = switch (file.kind) {
      FileKind.pdf => 'Document',
      FileKind.doc || FileKind.text => 'Document',
      FileKind.sheet => 'Spreadsheet',
      FileKind.slides => 'Presentation',
      FileKind.audio => 'Audio',
      FileKind.video => 'Video',
      FileKind.image => 'Image',
      FileKind.zip => 'Archive',
      FileKind.code => 'Source File',
      _ => 'File',
    };
    return '$label $noun';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final drive = ref.watch(driveControllerProvider);
    final folderName = file.parentId == null
        ? 'Drive'
        : drive.folder(file.parentId!)?.name ?? 'Drive';
    final created = DateTime.tryParse(file.createdAt)?.toLocal();
    final modified = DateTime.tryParse(file.modifiedAt)?.toLocal();
    String date(DateTime d) => DateFormat.yMMMd().add_jm().format(d);
    final owner = ref.read(authControllerProvider).user;
    final width = MediaQuery.sizeOf(context).width;
    final previewWidth = (width * .42).clamp(120.0, 190.0);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: IosNavigationBar.preferred(
        title: null,
        leading: IosNavigationBar.backButton(context),
        trailing: IosMoreButton(
          size: 44,
          tooltip: 'Actions for ${file.name}',
          menuTitle: itemStatusText(starred: file.starred, shared: file.shared),
          sectionsBuilder: (_) {
            final latest =
                ref.read(driveControllerProvider).file(file.id) ?? file;
            return [
              for (final destructive in [false, true])
                IosMenuSection([
                  for (final action in DriveItemActions.fileActions(
                    latest,
                  ).where((a) => a.destructive == destructive))
                    IosMenuItem(
                      label: action.label,
                      destructive: action.destructive,
                      onTap: () {
                        final active = ref.read(authControllerProvider).user;
                        if (!context.mounted ||
                            active?.userId != owner?.userId) {
                          return;
                        }
                        DriveItemActions.performFileAction(
                          context,
                          ref,
                          ref.read(driveControllerProvider).file(latest.id) ??
                              latest,
                          action.id,
                        );
                      },
                    ),
                ]),
            ];
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Center(
            child: SizedBox(
              width: previewWidth,
              child: AspectRatio(
                aspectRatio: file.kind == FileKind.image ? 1 : .78,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: IosBrowse.canvas(context),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: IosBrowse.hairline(context),
                        width: .5,
                      ),
                    ),
                  ),
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(14),
                    child: MediaThumb(
                      file: file,
                      fit: BoxFit.cover,
                      radius: 0,
                      showBackground: false,
                      fallback: IosFileGlyph(
                        kind: file.kind,
                        extension: extensionOf(file.name),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: FileNameText(
              file.name,
              maxLines: 3,
              textAlign: TextAlign.center,
              style: IosBrowse.headline(
                context,
              ).copyWith(fontSize: 20, height: 1.25, letterSpacing: -.45),
            ),
          ),
          const SizedBox(height: 6),
          ItemStatusLine(
            center: true,
            starred: file.starred,
            shared: file.shared,
            text: '${kindName(file)} · ${formatFileSize(file.size)}',
            textAlign: TextAlign.center,
            style: IosBrowse.subheadline(
              context,
            ).copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoButton.filled(
              minimumSize: const Size.fromHeight(50),
              borderRadius: BorderRadius.circular(100),
              onPressed: opening || file.isOptimistic ? null : onOpen,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (opening) ...[
                    const CupertinoActivityIndicator(color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      opening ? 'Opening…' : 'Open',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          IosGroup(
            title: 'Information',
            children: [
              IosRow(title: 'Kind', value: kindName(file)),
              IosRow(title: 'Size', value: formatFileSize(file.size)),
              IosRow(title: 'Location', value: folderName),
              if (created != null) IosRow(title: 'Added', value: date(created)),
              if (modified != null && file.modifiedAt != file.createdAt)
                IosRow(title: 'Modified', value: date(modified)),
              if (file.widthPx != null && file.heightPx != null)
                IosRow(
                  title: 'Dimensions',
                  value: '${file.widthPx} × ${file.heightPx}',
                ),
              if (file.duration != null)
                IosRow(
                  title: 'Duration',
                  value: formatDuration(file.duration!),
                ),
              if (file.starred || file.shared)
                IosRow(
                  title: 'Status',
                  value: itemStatusText(
                    starred: file.starred,
                    shared: file.shared,
                  ),
                ),
              if ((file.uploadStatus ?? 'available') != 'available')
                IosRow(title: 'Upload', value: formatUploadStatus(file)),
            ],
          ),
        ],
      ),
    );
  }
}
