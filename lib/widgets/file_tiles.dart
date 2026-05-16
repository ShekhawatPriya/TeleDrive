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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: SizedBox(
          width: 52,
          height: 52,
          child: isFolder
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : MediaThumb(file: file!, fit: BoxFit.contain),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
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
      ),
    );
  }
}

class FileCardTile extends StatelessWidget {
  const FileCardTile({
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox.expand(
                  child: MediaThumb(file: file, fit: BoxFit.contain),
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
                '${formatLabel(file)} • ${formatFileSize(file.size)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
