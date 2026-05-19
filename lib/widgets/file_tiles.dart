import 'package:flutter/material.dart';

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
    this.starred = false,
    this.shared = false,
    this.onMore,
    this.onStar,
    this.selected,
    this.onLongPress,
    super.key,
  });

  final String name;
  final String subtitle;
  final DriveFile? file;
  final bool isFolder;
  final bool starred;
  final bool shared;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onStar;
  final bool? selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inSelectMode = selected != null;
    final isShared = shared || (file?.shared ?? false);
    final isSelected = selected == true;

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
            if (isShared)
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
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: inSelectMode
          ? null
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

class FileCardTile extends StatelessWidget {
  const FileCardTile({
    required this.file,
    required this.onTap,
    this.onMore,
    this.selected,
    this.onLongPress,
    super.key,
  });
  final DriveFile file;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool? selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inSelectMode = selected != null;
    final isSelected = selected == true;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: isSelected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
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
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.md),
                      ),
                      child: MediaThumb(file: file, fit: BoxFit.cover),
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
                  if (file.shared)
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
                            color: scheme.onSurface,
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
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!inSelectMode)
                    IconButton(
                      onPressed: onMore,
                      icon: const Icon(Icons.more_vert),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 32, height: 32),
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
