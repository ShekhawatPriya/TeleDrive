import 'starred_badge.dart';
import 'item_status_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/file_type_detector.dart';
import '../models/drive_models.dart';
import 'file_list_tile.dart';
import 'ios/ios_browse.dart';
import 'media_thumb.dart';
import 'selection_indicator.dart';
import 'uploading_shimmer.dart';

class FileCardTile extends StatelessWidget {
  const FileCardTile({
    required this.file,
    required this.onTap,
    this.onMore,
    this.onRetry,
    this.onRemove,
    this.selected,
    this.onLongPress,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final bool? selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inSelectMode = selected != null;
    final isSelected = selected == true;
    final status = file.uploadStatus;
    final isFailed =
        file.isOptimistic && (status == 'failed' || status == 'cancelled');
    final isUploading = file.isOptimistic && !isFailed && status != 'uploaded';

    final borderSide = isSelected
        ? BorderSide(color: scheme.primary, width: 2)
        : isFailed
        ? BorderSide(color: scheme.error, width: 1.5)
        : BorderSide.none;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.platform == TargetPlatform.iOS
          ? Colors.transparent
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: borderSide,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: UploadingShimmer(
                      enabled: isUploading,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: ClipRRect(
                        borderRadius: theme.platform == TargetPlatform.iOS
                            ? BorderRadius.circular(18)
                            : const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                        child: MediaThumb(
                          file: file,
                          fit: BoxFit.cover,
                          fallback: theme.platform == TargetPlatform.iOS
                              ? IosFileGlyph(
                                  kind: file.kind,
                                  extension: extensionOf(file.name),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (theme.platform != TargetPlatform.iOS &&
                      !file.isOptimistic &&
                      (file.starred || file.shared))
                    Positioned(
                      right: 8,
                      top: 8,
                      child: ItemStatusIndicators(
                        starred: file.starred,
                        shared: file.shared,
                      ),
                    ),
                  if (theme.platform == TargetPlatform.iOS &&
                      file.starred &&
                      !isFailed &&
                      !isUploading)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: StarredBadge(size: 28),
                    ),
                  if (isUploading)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _StatusChip(label: formatUploadStatus(file)),
                    ),
                  if (isFailed)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.errorContainer.withValues(alpha: .55),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: scheme.onErrorContainer,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  if (inSelectMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: PremiumSelectionIndicator(
                        isSelected: isSelected,
                        isOverImage: true,
                        size: 22,
                      ),
                    ),
                  if (theme.platform == TargetPlatform.iOS &&
                      file.shared &&
                      !file.isOptimistic)
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: SharedBadge(size: 22),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                // iOS captions sit flush with the thumbnail, as in Recents.
                padding: theme.platform == TargetPlatform.iOS
                    ? const EdgeInsets.only(left: 2)
                    : const EdgeInsets.fromLTRB(12, 0, 4, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    // Only show the subtitle if we have enough vertical space (height >= 38)
                    final showSubtitle = height >= 38;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isFailed
                                        ? scheme.error
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (showSubtitle) ...[
                                const SizedBox(height: 2),
                                Flexible(
                                  child: Text(
                                    file.isOptimistic
                                        ? '${formatUploadStatus(file)} · ${formatFileSize(file.size)}'
                                        : '${formatLabel(file)} · ${formatFileSize(file.size)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isFailed
                                          ? scheme.error
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!inSelectMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isFailed) ...[
                                    _CompactIconButton(
                                      icon: Icons.refresh_rounded,
                                      color: scheme.error,
                                      tooltip: 'Retry',
                                      onPressed: onRetry,
                                    ),
                                    _CompactIconButton(
                                      icon: Icons.close_rounded,
                                      color: scheme.error,
                                      tooltip: 'Remove',
                                      onPressed: onRemove,
                                    ),
                                  ] else if (isUploading)
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else
                                    _CompactIconButton(
                                      icon: theme.platform == TargetPlatform.iOS
                                          ? CupertinoIcons.ellipsis
                                          : Icons.more_vert,
                                      color: scheme.onSurfaceVariant,
                                      tooltip: 'More',
                                      onPressed: onMore,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      iconSize: 20,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
