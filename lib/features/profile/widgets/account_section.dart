import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AccountSectionLabel extends StatelessWidget {
  const AccountSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class AccountSection extends StatelessWidget {
  const AccountSection({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class AccountActionRow extends StatelessWidget {
  const AccountActionRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = destructive ? scheme.error : scheme.onSurfaceVariant;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: destructive
              ? scheme.errorContainer.withValues(alpha: 0.55)
              : scheme.surfaceContainerHigh,
          borderRadius: AppRadii.smR,
        ),
        child: Icon(icon, color: tint, size: 20),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: destructive ? scheme.error : scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: value != null
          ? Text(
              value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : (onTap == null
                ? null
                : Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  )),
      onTap: onTap,
    );
  }
}
