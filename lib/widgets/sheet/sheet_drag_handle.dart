import 'package:flutter/material.dart';

/// Drag indicator for non-modal sheets. Modal bottom sheets pick up the
/// theme's `dragHandleColor` / `dragHandleSize` automatically and don't
/// need this widget.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.onSurfaceVariant.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
