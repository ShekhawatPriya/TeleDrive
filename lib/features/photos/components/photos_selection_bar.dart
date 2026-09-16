import 'package:flutter/material.dart';

import '../../../widgets/selection_toolbar.dart';

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
  Widget build(BuildContext context) => SelectionToolbar(
    count: selectedCount,
    onCancel: onCancel,
    actions: [
      (label: 'Share', icon: Icons.share_outlined, onPressed: onShare),
      (label: 'Move', icon: Icons.drive_file_move_outline, onPressed: onMove),
      (
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        onPressed: onDelete,
      ),
    ],
  );
}
