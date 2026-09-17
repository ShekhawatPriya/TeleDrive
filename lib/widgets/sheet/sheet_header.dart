import 'package:flutter/material.dart';

class SheetHeader extends StatelessWidget {
  const SheetHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingAccent,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final Color? leadingAccent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;

    final containerColor = leadingAccent != null
        ? leadingAccent!.withValues(alpha: .14)
        : scheme.secondaryContainer;
    final iconColor = leadingAccent ?? scheme.onSecondaryContainer;

    return Padding(
      padding: EdgeInsets.fromLTRB(ios ? 20 : 24, 0, 12, ios ? 8 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ] else if (leadingIcon != null) ...[
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
                  style:
                      (ios
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            fontSize: ios ? 17 : null,
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
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
