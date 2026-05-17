import 'package:flutter/material.dart';

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
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final VoidCallback? onStar;
  final bool? selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inSelectMode = selected != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: SizedBox(
          width: inSelectMode ? 84 : 52,
          height: 52,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected! ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected!
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .4),
                  ),
                ),
              SizedBox(
                width: 52,
                height: 52,
                child: isFolder
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          color: scheme.primary,
                        ),
                      )
                    : MediaThumb(file: file!, fit: BoxFit.cover),
              ),
            ],
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                    ? '${formatUploadStatus(file)} • ${formatFileSize(file.size)}'
                    : '${formatLabel(file)} • ${formatFileSize(file.size)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
