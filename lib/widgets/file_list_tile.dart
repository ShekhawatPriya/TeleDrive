import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/drive_models.dart';
import 'media_thumb.dart';
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
    final isFailed = isOptimistic && (status == 'failed' || status == 'cancelled');
    final isUploading = isOptimistic && !isFailed;

    final tile = ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: scheme.secondaryContainer.withValues(alpha: .35),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      minLeadingWidth: 56,
      horizontalTitleGap: AppSpacing.md,
      leading: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          children: [
            Positioned.fill(
              child: UploadingShimmer(
                enabled: isUploading,
                borderRadius: AppRadii.smR,
                child: isFolder
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: AppRadii.smR,
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          color: scheme.onSecondaryContainer,
                          size: 28,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: AppRadii.smR,
                        child: MediaThumb(file: file!, fit: BoxFit.cover),
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
                    size: 26,
                  ),
                ),
              ),
            if (isShared && !isOptimistic)
              const Positioned(
                right: 2,
                bottom: 2,
                child: SharedBadge(),
              ),
            if (inSelectMode)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSelected ? scheme.primary.withValues(alpha: .35) : Colors.transparent,
                    borderRadius: AppRadii.smR,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected ? Icon(Icons.check, size: 16, color: scheme.onPrimary) : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: isFailed ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isFailed ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
      trailing: inSelectMode
          ? null
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
                        IconButton(
                          onPressed: onStar,
                          icon: Icon(
                            starred ? Icons.star_rounded : Icons.star_border_rounded,
                            color: starred ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          tooltip: 'Star',
                        ),
                        IconButton(
                          onPressed: onMore,
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'More',
                        ),
                      ],
                    ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: tile,
    );
  }
}

class SharedBadge extends StatelessWidget {
  const SharedBadge({this.size = 18, super.key});
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
