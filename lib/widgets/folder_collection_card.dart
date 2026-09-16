import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/drive_models.dart';
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
    return Material(
      color: theme.platform == TargetPlatform.iOS
          ? scheme.surfaceContainerLow
          : scheme.surfaceContainer,
      shape: theme.platform == TargetPlatform.iOS
          ? RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(24))
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              folder.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                height: 1.2,
                                letterSpacing: -.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            folder.isOptimistic
                                ? 'Creating…'
                                : formatFileSize(folder.recursiveSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onMore,
                        tooltip: 'Actions for ${folder.name}',
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        theme.platform == TargetPlatform.iOS
                            ? (folder.shared
                                  ? CupertinoIcons.folder_badge_person_crop
                                  : CupertinoIcons.folder_fill)
                            : (folder.shared
                                  ? Icons.folder_shared_rounded
                                  : Icons.folder_rounded),
                        size: 64,
                        color: scheme.primary,
                      ),
                      if (folder.starred)
                        Positioned(
                          right: -4,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.bottomEnd,
                      child: folder.isOptimistic
                          ? Icon(
                              Icons.more_horiz_rounded,
                              color: scheme.onSurfaceVariant,
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${folder.recursiveFileCount}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontSize: 26, height: 1.1),
                                ),
                                Text(
                                  folder.recursiveFileCount == 1
                                      ? 'file'
                                      : 'files',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
