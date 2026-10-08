import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
    final ios = theme.platform == TargetPlatform.iOS;
    final items = [
      (
        label: 'Archive',
        icon: ios ? CupertinoIcons.archivebox : Icons.inventory_2_outlined,
        action: onArchiveTap,
      ),
      (
        label: 'Locked',
        icon: ios ? CupertinoIcons.lock : Icons.lock_outline_rounded,
        action: onLockedTap,
      ),
      (
        label: 'Trash',
        icon: ios ? CupertinoIcons.trash : Icons.delete_outline_rounded,
        action: onTrashTap,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
            final children = <Widget>[];
            for (var i = 0; i < items.length; i++) {
              final item = items[i];
              if (i > 0) {
                children.add(
                  stacked
                      ? Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: scheme.outlineVariant,
                        )
                      : SizedBox(
                          height: 32,
                          child: VerticalDivider(
                            width: 1,
                            color: scheme.outlineVariant,
                          ),
                        ),
                );
              }
              final icon = Icon(
                item.icon,
                size: 28,
                color: ios ? iosGraphite(scheme) : scheme.primary,
              );
              final label = Text(
                item.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.15,
                  color: scheme.onSurface,
                ),
              );
              final action = Semantics(
                button: true,
                child: InkWell(
                  onTap: item.action,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: stacked ? 16 : 18,
                    ),
                    child: stacked
                        ? Row(
                            children: [
                              icon,
                              const SizedBox(width: 14),
                              Expanded(child: label),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [icon, const SizedBox(height: 9), label],
                          ),
                  ),
                ),
              );
              children.add(stacked ? action : Expanded(child: action));
            }
            return stacked
                ? Column(mainAxisSize: MainAxisSize.min, children: children)
                : Row(children: children);
          },
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
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        topPadding ?? 24,
        20,
        bottomPadding ?? 12,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -.4,
          ),
        ),
      ),
    ),
  );
}
