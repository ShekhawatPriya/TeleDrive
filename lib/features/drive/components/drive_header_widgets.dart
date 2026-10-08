import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../widgets/ios/ios_browse.dart';

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
    if (ios) {
      return _IosSpaces(
        items: [
          (
            label: 'Archive',
            icon: CupertinoIcons.archivebox_fill,
            action: onArchiveTap,
          ),
          (
            label: 'Locked',
            icon: CupertinoIcons.lock_fill,
            action: onLockedTap,
          ),
          (label: 'Trash', icon: CupertinoIcons.trash_fill, action: onTrashTap),
        ],
      );
    }
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
                color: ios
                    ? CupertinoColors.systemBlue.resolveFrom(context)
                    : scheme.primary,
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

typedef _Space = ({String label, IconData icon, VoidCallback? action});

/// Archive, Locked and Trash as equal tiles: a tinted symbol over the
/// secondary surface with the name beneath it. At large text sizes the
/// spaces become rows so names never truncate.
class _IosSpaces extends StatelessWidget {
  const _IosSpaces({required this.items});
  final List<_Space> items;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(15) > 22;
    final fill = IosBrowse.fill(context);
    final label = IosBrowse.subheadline(context, weight: FontWeight.w600);
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: IosBrowse.gutter),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(22),
          child: ColoredBox(
            color: fill,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 64),
                      child: Divider(
                        height: .5,
                        thickness: .5,
                        color: IosBrowse.separator(context),
                      ),
                    ),
                  IosPressable(
                    onTap: items[i].action,
                    semanticLabel: items[i].label,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          IosSymbolBadge(items[i].icon),
                          const SizedBox(width: 14),
                          Expanded(child: Text(items[i].label, style: label)),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IosBrowse.gutter),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: IosPressable(
                onTap: items[i].action,
                semanticLabel: items[i].label,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 88),
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: MediaQuery.highContrastOf(context)
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            )
                          : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IosSymbolBadge(items[i].icon, size: 34),
                      const SizedBox(height: 12),
                      Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
