import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/safe_navigation.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';
import '../drive_controller.dart';

/// Horizontal recents strip shown on the drive home screen.
class DriveRecentsStrip extends StatelessWidget {
  const DriveRecentsStrip({
    required this.files,
    required this.onFileTap,
    this.onMore,
    super.key,
  });

  final List<DriveFile> files;
  final void Function(DriveFile file) onFileTap;
  final void Function(DriveFile file)? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 238 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => RecentFileCard(
          key: ValueKey(files[i].localId ?? files[i].id),
          file: files[i],
          onTap: () => onFileTap(files[i]),
          onMore: onMore != null ? () => onMore!(files[i]) : null,
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
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 240,
      child: Material(
        color: theme.platform == TargetPlatform.iOS
            ? Colors.transparent
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
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
                      radius: theme.platform == TargetPlatform.iOS ? 18 : 0,
                      decodeWidth: 640,
                    ),
                    if (file.starred)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 4, 12),
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
