import 'package:flutter/material.dart';

class SheetHeader extends StatelessWidget {
  const SheetHeader({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingAccent,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingAccent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final containerColor = leadingAccent != null
        ? leadingAccent!.withValues(alpha: .14)
        : scheme.secondaryContainer;
    final iconColor = leadingAccent ?? scheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: containerColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(leadingIcon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
