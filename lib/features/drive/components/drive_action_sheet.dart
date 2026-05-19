import 'package:flutter/material.dart';

import '../../../widgets/sheet/sheet_action_tile.dart';
import '../../../widgets/sheet/sheet_drag_handle.dart';
import '../../../widgets/sheet/sheet_header.dart';

class SheetActionItem {
  const SheetActionItem({
    required this.id,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool destructive;
}

class DriveActionSheet extends StatelessWidget {
  const DriveActionSheet({
    required this.title,
    required this.actions,
    this.subtitle,
    this.leadingIcon,
    this.leadingAccent,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingAccent;
  final List<SheetActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstDestructive = actions.indexWhere((a) => a.destructive);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetDragHandle(),
          SheetHeader(
            title: title,
            subtitle: subtitle,
            leadingIcon: leadingIcon,
            leadingAccent: leadingAccent,
          ),
          Divider(
            height: 1,
            color: scheme.outline.withValues(alpha: .6),
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < actions.length; i++) ...[
            if (i == firstDestructive && i > 0) ...[
              const SizedBox(height: 4),
              Divider(
                height: 1,
                color: scheme.outline.withValues(alpha: .6),
                indent: 20,
                endIndent: 20,
              ),
              const SizedBox(height: 4),
            ],
            SheetActionTile(
              label: actions[i].label,
              icon: actions[i].icon,
              destructive: actions[i].destructive,
              onTap: () => Navigator.pop(context, actions[i].id),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
