import 'package:flutter/material.dart';

class SheetActionTile extends StatelessWidget {
  const SheetActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final bool destructive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final iconColor = destructive ? scheme.error : scheme.onSurfaceVariant;
    final labelColor = destructive ? scheme.error : scheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: labelColor),
      ),
      subtitle: (subtitle == null || subtitle!.isEmpty)
          ? null
          : Text(subtitle!),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
      dense: compact,
      visualDensity: compact ? const VisualDensity(vertical: -2) : null,
      minLeadingWidth: 24,
      horizontalTitleGap: 16,
    );
  }
}
