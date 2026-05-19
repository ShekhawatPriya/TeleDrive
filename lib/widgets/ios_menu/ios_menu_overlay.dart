import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'ios_menu_models.dart';

/// Material 3 popup menu route. Anchors a tonal-elevation surface near the
/// triggering button, animates with the M3 emphasized-decelerate curve, and
/// lays sections out as `MenuItemButton`-style rows separated by 1dp dividers.
class IosMenuOverlayRoute extends PopupRoute<void> {
  IosMenuOverlayRoute({required this.anchor, required this.sections});

  final Rect anchor;
  final List<IosMenuSection> sections;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: .12);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => AppDurations.short3;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _MenuOverlay(
      anchor: anchor,
      sections: sections,
      animation: animation,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppEasing.emphasizedDecelerate,
      ),
      child: child,
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.anchor,
    required this.sections,
    required this.animation,
  });

  final Rect anchor;
  final List<IosMenuSection> sections;
  final Animation<double> animation;

  static const double _menuWidth = 280;
  static const double _gap = 8;
  static const double _edgeMargin = 12;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final spaceBelow = size.height - anchor.bottom - padding.bottom;
    final spaceAbove = anchor.top - padding.top;
    final showAbove = spaceBelow < 240 && spaceAbove > spaceBelow;

    var left = anchor.right - _menuWidth;
    if (left < _edgeMargin) left = _edgeMargin;
    if (left + _menuWidth > size.width - _edgeMargin) {
      left = size.width - _edgeMargin - _menuWidth;
    }
    final top = showAbove ? null : anchor.bottom + _gap;
    final bottom = showAbove ? size.height - anchor.top + _gap : null;

    final maxHeight = showAbove
        ? spaceAbove - _gap - _edgeMargin
        : spaceBelow - _gap - _edgeMargin;

    final originY = showAbove ? 1.0 : -1.0;
    final originX = ((anchor.center.dx - left) / _menuWidth) * 2 - 1;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          bottom: bottom,
          width: _menuWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight.clamp(120, 600)),
            child: ScaleTransition(
              alignment: Alignment(originX, originY),
              scale: CurvedAnimation(
                parent: animation,
                curve: AppEasing.emphasizedDecelerate,
              ).drive(Tween(begin: .85, end: 1)),
              child: _MenuCard(sections: sections),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.sections});
  final List<IosMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      type: MaterialType.card,
      color: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: scheme.shadow,
      elevation: AppElevation.level2,
      borderRadius: AppRadii.xsR,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
              const SizedBox(height: AppSpacing.xs),
              ...sections[i].items.map((item) => _MenuRow(item: item)),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final IosMenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelColor = item.destructive ? scheme.error : scheme.onSurface;
    final iconColor = item.destructive ? scheme.error : scheme.onSurfaceVariant;

    return InkWell(
      onTap: () {
        Navigator.of(context, rootNavigator: true).pop();
        item.onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: item.checked
                  ? Icon(Icons.check, size: 18, color: iconColor)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: labelColor,
                    ),
                  ),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (item.trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(item.trailingIcon, size: 20, color: iconColor),
            ],
          ],
        ),
      ),
    );
  }
}
