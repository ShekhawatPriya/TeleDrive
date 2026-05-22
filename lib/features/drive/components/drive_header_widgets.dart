import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Flat row that opens the Trash screen. Replaces the storage usage card on the
/// home screen — visually mirrors `_FlatActionTile` from the settings UI so
/// the surface feels continuous with the rest of the app.
class DriveTrashEntry extends StatelessWidget {
  const DriveTrashEntry({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Trash',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriveSectionHeader extends StatelessWidget {
  const DriveSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
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
