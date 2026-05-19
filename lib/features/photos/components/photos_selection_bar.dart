import 'package:flutter/material.dart';

class PhotosSelectionBar extends StatelessWidget {
  const PhotosSelectionBar({
    required this.selectedCount,
    required this.onCancel,
    required this.onShare,
    required this.onMove,
    required this.onDelete,
    super.key,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onShare;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasSelection = selectedCount > 0;
    return Material(
      color: scheme.surface,
      shape: Border(bottom: BorderSide(color: scheme.outline)),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancel',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                color: scheme.onSurface,
              ),
              const SizedBox(width: 4),
              Text(
                hasSelection ? '$selectedCount selected' : 'Select items',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Share',
                onPressed: hasSelection ? onShare : null,
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                tooltip: 'Move',
                onPressed: hasSelection ? onMove : null,
                icon: const Icon(Icons.drive_file_move_outline),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: hasSelection ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
