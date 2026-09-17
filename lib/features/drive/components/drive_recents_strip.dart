import '../../../widgets/starred_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/safe_navigation.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
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
                      if (file.starred)
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
                          icon: const Icon(Icons.more_horiz_rounded),
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
