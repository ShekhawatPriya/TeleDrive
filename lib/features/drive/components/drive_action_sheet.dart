import 'package:flutter/material.dart';

import '../../../models/drive_models.dart';
import '../../../widgets/google_drive_icon.dart';
import '../../../widgets/media_thumb.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Build the leading preview widget in the center
    Widget? leadingWidget;
    if (file != null) {
      leadingWidget = SizedBox(
        width: 64,
        height: 64,
        child: MediaThumb(
          file: file!,
          fit: BoxFit.cover,
          radius: 16,
          showBackground: true,
        ),
      );
    } else if (folder != null) {
      leadingWidget = GoogleDriveIcon.folder(
        isShared: folder!.shared,
        size: 64,
      );
    } else if (leadingIcon != null) {
      leadingWidget = Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color:
              leadingAccent?.withValues(alpha: 0.15) ??
              scheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          leadingIcon,
          size: 32,
          color: leadingAccent ?? scheme.onSecondaryContainer,
        ),
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
          // Top spacing & Drag handle is managed globally by bottomSheetTheme.showDragHandle.
          // Add a small spacing below the handle.
          const SizedBox(height: 8),

          // Centered file/folder preview thumbnail
          if (leadingWidget != null) ...[
            Center(child: leadingWidget),
            const SizedBox(height: 16),
          ],

          // Centered filename
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),

          // Centered subtitle (metadata)
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Horizontal Quick Actions Row (Share, Download, Star)
          if (quickActions.isNotEmpty) ...[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < quickActions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 20),
                      QuickActionButton(
                        action: quickActions[i],
                        onTap: () => Navigator.pop(context, quickActions[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Vertical standard list actions (Move, Lock, Archive)
          for (final action in otherActions)
            ListActionTile(
              label: action.label,
              icon: action.icon,
              onTap: () => Navigator.pop(context, action.id),
            ),

          // Divider before destructive actions (Delete)
          if (destructiveActions.isNotEmpty &&
              (quickActions.isNotEmpty || otherActions.isNotEmpty))
            const Divider(height: 24, thickness: 1, indent: 24, endIndent: 24),

          // Destructive action (Delete)
          for (final action in destructiveActions)
            ListActionTile(
              label: action.label,
              icon: action.icon,
              destructive: true,
              onTap: () => Navigator.pop(context, action.id),
            ),

          const SizedBox(height: 12),
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
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
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

class ListActionTile extends StatelessWidget {
  const ListActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final containerColor = destructive
        ? scheme.error.withValues(alpha: 0.20)
        : scheme.onSurface.withValues(alpha: 0.08);

    final iconColor = destructive ? scheme.error : scheme.onSurface;

    final labelColor = destructive ? scheme.error : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: labelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
