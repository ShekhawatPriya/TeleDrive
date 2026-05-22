import 'package:flutter/material.dart';

import '../../../models/drive_models.dart';
import '../../../widgets/google_drive_icon.dart';
import '../../../widgets/media_thumb.dart';
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
    this.file,
    this.folder,
    this.leadingIcon,
    this.leadingAccent,
    super.key,
  });

  final String title;
  final String? subtitle;
  final DriveFile? file;
  final DriveFolder? folder;
  final IconData? leadingIcon;
  final Color? leadingAccent;
  final List<SheetActionItem> actions;

  @override
  Widget build(BuildContext context) {
    // Build the leading widget for the sheet header (exact pixel-perfect replica sizes and shapes)
    Widget? leadingWidget;
    if (file != null) {
      leadingWidget = SizedBox(
        width: 48,
        height: 48,
        child: MediaThumb(
          file: file!,
          fit: BoxFit.cover,
          radius: 10,
          showBackground: true,
        ),
      );
    } else if (folder != null) {
      leadingWidget = GoogleDriveIcon.folder(
        isShared: folder!.shared,
        size: 48,
      );
    }

    // Categorize actions: horizontal quick actions vs vertical list actions
    final quickActionIds = {
      'share',
      'revoke_share',
      'download',
      'star',
      'unstar',
    };
    final quickActions = actions
        .where((a) => quickActionIds.contains(a.id))
        .toList();
    final otherActions = actions
        .where((a) => !quickActionIds.contains(a.id) && !a.destructive)
        .toList();
    final destructiveActions = actions.where((a) => a.destructive).toList();

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header showing thumbnail/icon, filename, and details
          SheetHeader(
            title: title,
            subtitle: subtitle,
            leading: leadingWidget,
            leadingIcon: leadingIcon,
            leadingAccent: leadingAccent,
          ),

          // Horizontal Quick Actions Row
          if (quickActions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: quickActions.map((action) {
                      return QuickActionButton(
                        action: action,
                        onTap: () => Navigator.pop(context, action.id),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Vertical actions (e.g., Move, Rename)
          for (final action in otherActions)
            SheetActionTile(
              label: action.label,
              icon: action.icon,
              destructive: action.destructive,
              compact: true,
              onTap: () => Navigator.pop(context, action.id),
            ),

          // Divider before destructive actions (e.g. Delete)
          if (destructiveActions.isNotEmpty &&
              (quickActions.isNotEmpty || otherActions.isNotEmpty))
            const Divider(height: 8, indent: 24, endIndent: 24),

          // Destructive actions
          for (final action in destructiveActions)
            SheetActionTile(
              label: action.label,
              icon: action.icon,
              destructive: action.destructive,
              compact: true,
              onTap: () => Navigator.pop(context, action.id),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    required this.action,
    required this.onTap,
    super.key,
  });

  final SheetActionItem action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(action.icon, color: scheme.onSurface, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
