import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/file_type_detector.dart';
import '../models/drive_models.dart';
import 'media_thumb.dart';

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
    final isUploading = isOptimistic && !isFailed;

    final tile = ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: scheme.secondaryContainer.withValues(alpha: .35),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs,
      ),
      minLeadingWidth: 56,
      horizontalTitleGap: AppSpacing.md,
      leading: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          children: [
            Positioned.fill(
              child: _UploadingShimmer(
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
                    color: isSelected
                        ? scheme.primary.withValues(alpha: .35)
                        : Colors.transparent,
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
                          color: isSelected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                          : null,
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
                            starred
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: starred
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
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
    final isFailed = file.isOptimistic &&
        (status == 'failed' || status == 'cancelled');
    final isUploading = file.isOptimistic && !isFailed;

    final borderSide = isSelected
        ? BorderSide(color: scheme.primary, width: 2)
        : isFailed
            ? BorderSide(color: scheme.error, width: 1.5)
            : BorderSide.none;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: borderSide,
      ),
      child: InkWell(
        borderRadius: AppRadii.mdR,
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
                    child: _UploadingShimmer(
                      enabled: isUploading,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.md),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadii.md),
                        ),
                        child: MediaThumb(file: file, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  if (isUploading)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _StatusChip(
                        label: formatUploadStatus(file),
                      ),
                    ),
                  if (isFailed)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.errorContainer.withValues(alpha: .55),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadii.md),
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
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? scheme.primary : scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                            : null,
                      ),
                    ),
                  if (file.shared && !file.isOptimistic)
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: SharedBadge(size: 22),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isFailed ? scheme.error : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          file.isOptimistic
                              ? '${formatUploadStatus(file)} · ${formatFileSize(file.size)}'
                              : '${formatLabel(file)} · ${formatFileSize(file.size)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                isFailed ? scheme.error : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!inSelectMode)
                    if (isFailed)
                      _CompactIconButton(
                        icon: Icons.refresh_rounded,
                        color: scheme.error,
                        tooltip: 'Retry',
                        onPressed: onRetry,
                      ),
                  if (!inSelectMode)
                    if (isFailed)
                      _CompactIconButton(
                        icon: Icons.close_rounded,
                        color: scheme.error,
                        tooltip: 'Remove',
                        onPressed: onRemove,
                      )
                    else if (isUploading)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      _CompactIconButton(
                        icon: Icons.more_vert,
                        color: scheme.onSurfaceVariant,
                        tooltip: 'More',
                        onPressed: onMore,
                      ),
                ],
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
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [child] with a visible, premium shimmer sweep and breathing pulse while [enabled] is true. 
/// When disabled, returns the child untouched with no animation overhead.
class _UploadingShimmer extends StatefulWidget {
  const _UploadingShimmer({
    required this.enabled,
    required this.child,
    required this.borderRadius,
  });

  final bool enabled;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<_UploadingShimmer> createState() => _UploadingShimmerState();
}

class _UploadingShimmerState extends State<_UploadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.enabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _UploadingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // Animated breathing/pulsing overlay with primary brand colors for strong visibility
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Opacity(
                  opacity: _pulseAnimation.value,
                  child: Shimmer.fromColors(
                    baseColor: scheme.primaryContainer.withValues(alpha: .35),
                    highlightColor: scheme.primary.withValues(alpha: .75),
                    period: const Duration(milliseconds: 1200),
                    child: const ColoredBox(
                      color: Colors.white, // Opaque mask for high-contrast colors
                    ),
                  ),
                ),
              );
            },
          ),
          // Pulsing premium glowing border outline
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: _pulseAnimation.value * 0.7),
                      width: 2.0,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
