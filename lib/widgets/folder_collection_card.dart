import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/drive_models.dart';
import 'starred_badge.dart';
import 'item_status_indicators.dart';
import '../core/utils/file_type_detector.dart';

class FolderCollectionCard extends StatelessWidget {
  const FolderCollectionCard({
    required this.folder,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
    super.key,
  });
  final DriveFolder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final folderInk = ios
        ? CupertinoColors.systemBlue.resolveFrom(context)
        : scheme.primary;
    final count = folder.recursiveFileCount;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        ios
                            ? (folder.shared
                                  ? CupertinoIcons.folder_badge_person_crop
                                  : CupertinoIcons.folder_fill)
                            : Icons.folder_rounded,
                        size: 32,
                        color: folderInk,
                      ),
                      if (ios && folder.starred)
                        Positioned(
                          right: -3,
                          bottom: 0,
                          child: const StarredBadge(),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (onMore != null)
                    SizedBox(
                      width: ios ? 44 : 48,
                      height: ios ? 44 : 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onMore,
                        tooltip: 'Actions for ${folder.name}',
                        icon: Icon(
                          ios
                              ? CupertinoIcons.ellipsis
                              : Icons.more_horiz_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 44),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      height: 1.2,
                      letterSpacing: -.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (!ios && (folder.starred || folder.shared)) ...[
                ItemStatusIndicators(
                  starred: folder.starred,
                  shared: folder.shared,
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 6),
              Text(
                folder.isOptimistic
                    ? 'Creating…'
                    : '$count ${count == 1 ? 'file' : 'files'} · ${formatFileSize(folder.recursiveSize)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
