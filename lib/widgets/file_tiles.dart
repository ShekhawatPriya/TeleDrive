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
    final scheme = Theme.of(context).colorScheme;
    final inSelectMode = selected != null;
    final isShared = shared || (file?.shared ?? false);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        minLeadingWidth: inSelectMode ? 96 : 64,
        leading: SizedBox(
          width: inSelectMode ? 96 : 64,
          height: 64,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    selected!
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected!
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .4),
                  ),
                ),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: isFolder
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: .72),
                                ),
                              ),
                              child: Icon(
                                Icons.folder_outlined,
                                color: scheme.onSurface,
                                size: 30,
                              ),
                            )
                          : MediaThumb(file: file!, fit: BoxFit.cover),
                    ),
                    if (isShared)
                      const Positioned(
                        right: 4,
                        bottom: 4,
                        child: SharedBadge(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
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
                    icon: Icon(starred ? Icons.star : Icons.star_border),
                    tooltip: 'Star',
                  ),
                  IconButton(
                    onPressed: onMore,
                    icon: const Icon(Icons.more_horiz),
                    tooltip: 'More',
                  ),
                ],
              ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class SharedBadge extends StatelessWidget {
  const SharedBadge({this.size = 16, super.key});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      child: Icon(
        Icons.link_rounded,
        size: size * 0.65,
        color: scheme.onPrimary,
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
    final scheme = Theme.of(context).colorScheme;
    final inSelectMode = selected != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: MediaThumb(file: file, fit: BoxFit.cover),
                    ),
                    if (inSelectMode)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Icon(
                          selected!
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected!
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .55),
                        ),
                      ),
                    if (file.shared)
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: SharedBadge(size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!inSelectMode)
                    IconButton(
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz),
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              Text(
                file.isOptimistic
                    ? '${formatUploadStatus(file)} \u00b7 ${formatFileSize(file.size)}'
                    : '${formatLabel(file)} \u00b7 ${formatFileSize(file.size)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
