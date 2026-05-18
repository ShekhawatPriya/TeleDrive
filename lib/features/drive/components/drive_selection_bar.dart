import 'package:flutter/material.dart';

class DriveSelectionBar extends StatelessWidget {
  const DriveSelectionBar({
    required this.selectedCount,
    required this.onCancel,
    required this.onShare,
    required this.onStar,
    required this.onMove,
    required this.onDelete,
    super.key,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onShare;
  final VoidCallback onStar;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSelection = selectedCount > 0;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              Text(
                hasSelection ? '$selectedCount selected' : 'Select items',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Share',
                onPressed: hasSelection ? onShare : null,
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                tooltip: 'Star',
                onPressed: hasSelection ? onStar : null,
                icon: const Icon(Icons.star_border),
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
