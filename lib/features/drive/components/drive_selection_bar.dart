import 'package:flutter/material.dart';

import '../../../widgets/selection_toolbar.dart';

/// M3 contextual top app bar shown when one or more drive items are selected.
/// Replaces the regular header on the drive / folder screens.
class DriveSelectionBar extends StatelessWidget {
  const DriveSelectionBar({
    required this.selectedCount,
    this.actionsOnly = false,
    this.onSelectAll,
    this.onClear,
    required this.onCancel,
    required this.onShare,
    required this.onStar,
    required this.onMove,
    required this.onDelete,
    super.key,
  });

  final bool actionsOnly;
  final VoidCallback? onSelectAll, onClear;
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onShare;
  final VoidCallback onStar;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SelectionToolbar(
    count: selectedCount,
    actionsOnly: actionsOnly,
    onSelectAll: onSelectAll,
    onClear: onClear,
    onCancel: onCancel,
    actions: [
      (label: 'Share', icon: Icons.share_outlined, onPressed: onShare),
      (label: 'Star', icon: Icons.star_outline_rounded, onPressed: onStar),
      (label: 'Move', icon: Icons.drive_file_move_outline, onPressed: onMove),
      (
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        onPressed: onDelete,
      ),
    ],
  );
}
