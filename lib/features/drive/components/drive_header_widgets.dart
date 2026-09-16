import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Horizontal row of pill-shaped quick action buttons (Trash, Archive, Locked)
/// shown above the Recent strip on the drive home. Archive and Locked are
/// available as dedicated recovery and organization destinations.
class DriveQuickActions extends StatelessWidget {
  const DriveQuickActions({
    this.onTrashTap,
    this.onArchiveTap,
    this.onLockedTap,
    super.key,
  });

  final VoidCallback? onTrashTap;
  final VoidCallback? onArchiveTap;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _QuickActionPill(
            icon: Icons.delete_outline_rounded,
            label: 'Trash',
            onTap: onTrashTap,
          ),
          _QuickActionPill(
            icon: Icons.inventory_2_outlined,
            label: 'Archive',
            onTap: onArchiveTap,
          ),
          _QuickActionPill(
            icon: Icons.lock_outline_rounded,
            label: 'Locked',
            onTap: onLockedTap,
          ),
        ],
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: theme.textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }
}

class DriveSectionHeader extends StatelessWidget {
  const DriveSectionHeader(
    this.title, {
    this.topPadding,
    this.bottomPadding,
    super.key,
  });
  final String title;
  final double? topPadding;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          topPadding ?? AppSpacing.lg,
          AppSpacing.md,
          bottomPadding ?? AppSpacing.xs,
        ),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
