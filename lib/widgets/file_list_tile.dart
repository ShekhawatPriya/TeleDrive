import 'starred_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../core/utils/file_type_detector.dart';

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
    final ios = theme.platform == TargetPlatform.iOS;
    final inSelectMode = selected != null;
    final isShared = shared || (file?.shared ?? false);
    final isSelected = selected == true;
    final status = file?.uploadStatus;
    final isFailed =
        isOptimistic && (status == 'failed' || status == 'cancelled');
    final isUploading = isOptimistic && !isFailed && status != 'uploaded';

    final thumbnail = SizedBox(
      width: ios ? 40 : 48,
      height: ios ? 40 : 48,
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
                      radius: ios ? 6 : AppRadii.sm,
                      showBackground: false,
                    ),
            ),
          ),
          if (starred && !isFailed && !isUploading)
            Positioned(
              right: 0,
              bottom: 0,
              child: StarredBadge(backgroundColor: scheme.surface),
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
            Positioned(
              right: 0,
              bottom: starred ? 22 : 0,
              child: SharedBadge(size: 14),
            ),
        ],
      ),
    );

    final tile = ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: ios
          ? Colors.transparent
          : scheme.secondaryContainer.withValues(alpha: .35),
      minTileHeight: ios ? 64 : null,
      minVerticalPadding: ios ? 6 : null,
      contentPadding: ios
          ? (inSelectMode
                ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm)
                : EdgeInsets.zero)
          : const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.xxs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
      minLeadingWidth: ios ? 40 : 48,
      horizontalTitleGap: ios ? 12 : AppSpacing.md,
      leading: ios && inSelectMode
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumSelectionIndicator(isSelected: isSelected),
                const SizedBox(width: 16),
                thumbnail,
              ],
            )
          : thumbnail,
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: ios ? FontWeight.w400 : FontWeight.w600,
          color: isFailed ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        ios && file != null && !isOptimistic
            ? '${formatLabel(file!)} · ${formatFileSize(file!.size)} · ${_fileDate(file!.modifiedAt)}'
            : subtitle,
        maxLines: ios && inSelectMode ? null : 2,
        overflow: ios && inSelectMode
            ? TextOverflow.visible
            : TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: ios ? 13 : null,
          color: isFailed ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
      trailing: ios && inSelectMode
          ? null
          : inSelectMode
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
                if (!ios && onStar != null)
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
                  icon: Icon(ios ? CupertinoIcons.ellipsis : Icons.more_vert),
                  tooltip: 'Actions for $name',
                ),
              ],
            ),
    );

    if (ios && inSelectMode) {
      final highContrast = MediaQuery.highContrastOf(context);
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: AppSpacing.xxs,
        ),
        child: Material(
          color: isSelected
              ? (highContrast
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerLow)
              : Colors.transparent,
          shape: RoundedSuperellipseBorder(
            borderRadius: AppRadii.lgR,
            side: highContrast && isSelected
                ? BorderSide(color: scheme.outline, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.short3,
          child: tile,
        ),
      );
    }
    if (ios) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              tile,
              Divider(
                height: .5,
                thickness: .5,
                indent: 52,
                color: scheme.outlineVariant.withValues(alpha: .45),
              ),
            ],
          ),
        ),
      );
    }
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

String _fileDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null ? 'Unknown date' : DateFormat('d MMM y').format(date);
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
