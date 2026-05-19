import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Contextual top app bar shown when one or more photos are selected.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasSelection = selectedCount > 0;
    return Material(
      color: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      elevation: AppElevation.level2,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    hasSelection ? '$selectedCount selected' : 'Select items',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: hasSelection ? onShare : null,
                  icon: const Icon(Icons.share_outlined),
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
      ),
    );
  }
}
