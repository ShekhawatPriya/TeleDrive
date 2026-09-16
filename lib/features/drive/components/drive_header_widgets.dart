import 'package:flutter/material.dart';

/// Organizational destinations remain reachable without leading with Trash.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = [
      (
        label: 'Archive',
        icon: Icons.inventory_2_outlined,
        action: onArchiveTap,
      ),
      (label: 'Locked', icon: Icons.lock_outline_rounded, action: onLockedTap),
      (label: 'Trash', icon: Icons.delete_outline_rounded, action: onTrashTap),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in items)
                SizedBox(
                  width: largeText
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 20) / 3,
                  child: Material(
                    color: theme.platform == TargetPlatform.iOS
                        ? Colors.transparent
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: item.action,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.icon, color: scheme.primary, size: 24),
                            const SizedBox(height: 18),
                            Text(
                              item.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        topPadding ?? 28,
        24,
        bottomPadding ?? 14,
      ),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ),
  );
}
