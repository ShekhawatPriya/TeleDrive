import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../core/theme/app_theme.dart';
import '../models/drive_models.dart';
import 'google_drive_icon.dart';
import 'media_thumb.dart';
import 'selection_indicator.dart';
import 'uploading_shimmer.dart';

class FileListTile extends StatelessWidget {
  const FileListTile({
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.file,
    this.isFolder = false,
    this.isOptimistic = false,
    this.starred = false,
    this.shared = false,
    this.onMore,
    this.onStar,
    this.onRetry,
    this.onRemove,
    this.selected,
    this.onLongPress,
    super.key,
  });

  final String name;
  final String subtitle;
  final DriveFile? file;
  final bool isFolder;
  final bool isOptimistic;
  final bool starred;
  final bool shared;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onStar;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final bool? selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inSelectMode = selected != null;
    final isShared = shared || (file?.shared ?? false);
    final isSelected = selected == true;
    final status = file?.uploadStatus;
    final isFailed =
        isOptimistic && (status == 'failed' || status == 'cancelled');
    final isUploading = isOptimistic && !isFailed && status != 'uploaded';

    final tile = ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: scheme.secondaryContainer.withValues(alpha: .35),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      minLeadingWidth: 48,
      horizontalTitleGap: AppSpacing.md,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          children: [
            Positioned.fill(
              child: UploadingShimmer(
                enabled: isUploading,
                borderRadius: AppRadii.smR,
                child: isFolder
                    ? Center(
                        child: theme.platform == TargetPlatform.iOS
                            ? Icon(
                                CupertinoIcons.folder_fill,
                                size: 36,
                                color: scheme.primary,
                              )
                            : GoogleDriveIcon.folder(
                                isShared: isShared,
                                size: 34,
                              ),
                      )
                    : MediaThumb(
                        file: file!,
                        fit: BoxFit.cover,
                        radius: AppRadii.sm,
                        showBackground: false,
                      ),
              ),
            ),
            if (isFailed)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: .55),
                    borderRadius: AppRadii.smR,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: scheme.onErrorContainer,
                    size: 20,
                  ),
                ),
              ),
            if (isShared && !isOptimistic)
              const Positioned(
                right: 0,
                bottom: 0,
                child: SharedBadge(size: 14),
              ),
          ],
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isFailed ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isFailed ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
      trailing: inSelectMode
          ? Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: PremiumSelectionIndicator(isSelected: isSelected),
            )
          : isFailed
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  color: scheme.error,
                  tooltip: 'Retry',
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  color: scheme.error,
                  tooltip: 'Remove',
                ),
              ],
            )
          : isUploading
          ? const Padding(
              padding: EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onStar != null)
                  IconButton(
                    onPressed: onStar,
                    icon: Icon(
                      starred ? Icons.star_rounded : Icons.star_border_rounded,
                      color: starred ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    tooltip: starred ? 'Unstar $name' : 'Star $name',
                  ),
                IconButton(
                  onPressed: onMore,
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Actions for $name',
                ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: tile,
      ),
    );
  }
}

class SharedBadge extends StatelessWidget {
  const SharedBadge({this.size = 14, super.key});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.tertiary,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 2),
      ),
      child: Icon(
        Icons.link_rounded,
        size: size * 0.6,
        color: scheme.onTertiary,
      ),
    );
  }
}
