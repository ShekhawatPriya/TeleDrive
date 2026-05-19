import 'package:flutter/material.dart';

import '../../../widgets/sheet/sheet_action_tile.dart';
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
    final firstDestructive = actions.indexWhere((a) => a.destructive);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: title,
            subtitle: subtitle,
            leadingIcon: leadingIcon,
            leadingAccent: leadingAccent,
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i == firstDestructive && i > 0)
              const Divider(height: 1, indent: 24, endIndent: 24),
            SheetActionTile(
              label: actions[i].label,
              icon: actions[i].icon,
              destructive: actions[i].destructive,
              onTap: () => Navigator.pop(context, actions[i].id),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
