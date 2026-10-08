import '../../../widgets/starred_badge.dart';
import '../../../widgets/item_status_indicators.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/safe_navigation.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/ios/ios_browse.dart';
import '../../../widgets/media_thumb.dart';
import '../drive_controller.dart';
import 'drive_item_context_menu.dart';

/// Horizontal recents strip shown on the drive home screen.
class DriveRecentsStrip extends StatelessWidget {
  const DriveRecentsStrip({
    required this.files,
    required this.onFileTap,
    this.onMore,
    this.onSelect,
    super.key,
  });

  final List<DriveFile> files;
  final void Function(DriveFile file) onFileTap;
  final void Function(DriveFile file)? onMore;
  final void Function(DriveFile file)? onSelect;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _IosRecentsRail(
        files: files,
        onFileTap: onFileTap,
        onSelect: onSelect,
      );
    }
    return SizedBox(
      height: 204 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemBuilder: (_, i) => RecentFileCard(
          key: ValueKey(files[i].localId ?? files[i].id),
          file: files[i],
          onTap: () => onFileTap(files[i]),
          onMore: onMore != null ? () => onMore!(files[i]) : null,
          onSelect: onSelect != null ? () => onSelect!(files[i]) : null,
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: files.length,
      ),
    );
  }
}

class RecentFileCard extends StatelessWidget {
  const RecentFileCard({
    required this.file,
    required this.onTap,
    this.onMore,
    this.onSelect,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 72).clamp(220.0, 280.0),
      child: DriveItemContextMenu(
        file: file,
        enabled: onSelect != null,
        onOpen: onTap,
        onSelect: onSelect ?? () {},
        trailingClearance: 48,
        child: Material(
          color: theme.platform == TargetPlatform.iOS
              ? scheme.surfaceContainerLow
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MediaThumb(
                        file: file,
                        fit: BoxFit.cover,
                        radius: 0,
                        decodeWidth: 640,
                      ),
                      if (theme.platform != TargetPlatform.iOS &&
                          !file.isOptimistic &&
                          (file.starred || file.shared))
                        Positioned(
                          top: 12,
                          right: 12,
                          child: ItemStatusIndicators(
                            starred: file.starred,
                            shared: file.shared,
                          ),
                        ),
                      if (theme.platform == TargetPlatform.iOS && file.starred)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: const StarredBadge(size: 28),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${formatLabel(file)} · ${formatFileSize(file.size)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (onMore != null)
                        IconButton(
                          onPressed: onMore,
                          tooltip: 'Actions for ${file.name}',
                          icon: Icon(
                            Theme.of(context).platform == TargetPlatform.iOS
                                ? CupertinoIcons.ellipsis
                                : Icons.more_horiz_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recents as an image-first rail: square thumbnails with their captions
/// directly on the page. Two and a half tiles show at rest so the rail reads
/// as scrollable; item actions come from the native hold menu.
class _IosRecentsRail extends StatelessWidget {
  const _IosRecentsRail({
    required this.files,
    required this.onFileTap,
    this.onSelect,
  });
  final List<DriveFile> files;
  final void Function(DriveFile file) onFileTap;
  final void Function(DriveFile file)? onSelect;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    final width = MediaQuery.sizeOf(context).width;
    final scaler = MediaQuery.textScalerOf(context);
    // Large text widens the tiles and gives each caption line room to wrap
    // instead of truncating names to a few letters.
    final large = scaler.scale(15) > 22;
    final lines = large ? 2 : 1;
    final tile = large
        ? (width - IosBrowse.gutter * 2 - gap) * .8
        : ((width - IosBrowse.gutter - gap * 2) / 2.5).clamp(124.0, 176.0);
    final thumb = large ? tile * .7 : tile;
    final caption =
        8 + (scaler.scale(15) * 1.34 + scaler.scale(13) * 1.39) * lines + 2;
    return SizedBox(
      height: thumb + caption + 4,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: IosBrowse.gutter),
        scrollDirection: Axis.horizontal,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: gap),
        itemBuilder: (_, i) {
          final file = files[i];
          return SizedBox(
            key: ValueKey(file.localId ?? file.id),
            width: tile,
            child: DriveItemContextMenu(
              file: file,
              enabled: onSelect != null,
              onOpen: () => onFileTap(file),
              onSelect: onSelect == null ? () {} : () => onSelect!(file),
              child: IosPressable(
                onTap: () => onFileTap(file),
                semanticLabel:
                    '${file.name}, ${formatLabel(file)}, ${formatFileSize(file.size)}',
                child: _IosRecentTile(file: file, height: thumb, lines: lines),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IosRecentTile extends StatelessWidget {
  const _IosRecentTile({
    required this.file,
    required this.height,
    required this.lines,
  });
  final DriveFile file;
  final double height;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRSuperellipse(
                borderRadius: radius,
                child: ColoredBox(
                  color: IosBrowse.fill(context),
                  child: MediaThumb(
                    file: file,
                    fit: BoxFit.cover,
                    radius: 0,
                    showBackground: false,
                    decodeWidth: 640,
                    fallback: IosFileGlyph(
                      kind: file.kind,
                      extension: extensionOf(file.name),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: radius,
                      side: BorderSide(
                        color: IosBrowse.hairline(context),
                        width: .5,
                      ),
                    ),
                  ),
                ),
              ),
              if (file.starred && !file.isOptimistic)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: StarredBadge(size: 24),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          file.name,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: IosBrowse.subheadline(context, weight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          file.isOptimistic
              ? formatUploadStatus(file)
              : '${formatLabel(file)} · ${formatFileSize(file.size)}',
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: IosBrowse.footnote(context),
        ),
      ],
    );
  }
}

/// Helper to push the file detail route and record recent access.
void openDriveFile(BuildContext context, WidgetRef ref, DriveFile file) {
  if (file.isOptimistic) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(formatUploadStatus(file))));
    return;
  }
  ref.read(driveControllerProvider).markAccessed(file.id);
  context.safePush('/file/${file.id}');
}
