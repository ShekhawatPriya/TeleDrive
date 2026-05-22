import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Horizontal row of pill-shaped quick action buttons (Trash, Archive, Locked)
/// shown above the Recent strip on the drive home. Archive and Locked are
/// visual-only at this stage; only Trash navigates.
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
      child: Row(
        children: [
          _QuickActionPill(
            icon: Icons.delete_outline_rounded,
            label: 'Trash',
            onTap: onTrashTap,
          ),
          const SizedBox(width: AppSpacing.sm),
          _QuickActionPill(
            icon: Icons.inventory_2_outlined,
            label: 'Archive',
            onTap: onArchiveTap,
          ),
          const SizedBox(width: AppSpacing.sm),
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

    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
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
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
