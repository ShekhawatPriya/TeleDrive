import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'ios_menu_models.dart';

/// Material 3 popup menu route. Anchors a tonal-elevation surface near the
/// triggering button, animates with the M3 emphasized curve, and lays
/// sections out as `MenuItemButton`-style rows separated by a thin trough.
class IosMenuOverlayRoute extends PopupRoute<void> {
  IosMenuOverlayRoute({required this.anchor, required this.sections});

  final Rect anchor;
  final List<IosMenuSection> sections;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: .22);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => AppDurations.medium2;

  @override
  Duration get reverseTransitionDuration => AppDurations.short3;

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
      opacity: CurvedAnimation(parent: animation, curve: AppEasing.emphasized),
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

  static const double _menuWidth = 268;
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
              ).drive(Tween(begin: .92, end: 1)),
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
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: scheme.shadow,
      elevation: AppElevation.level3,
      borderRadius: AppRadii.mdR,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.mdR,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .6),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxs,
                      ),
                      color: scheme.surfaceContainerLowest.withValues(
                        alpha: .55,
                      ),
                    ),
                  ...sections[i].items.map((item) => _MenuRow(item: item)),
                ],
              ],
            ),
          ),
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
    final destructive = item.destructive;
    final labelColor = destructive ? scheme.error : scheme.onSurface;
    final iconColor = destructive ? scheme.error : scheme.onSurfaceVariant;
    final highlight = destructive
        ? scheme.errorContainer.withValues(alpha: .35)
        : scheme.onSurface.withValues(alpha: .06);
    final splash = destructive
        ? scheme.error.withValues(alpha: .12)
        : scheme.primary.withValues(alpha: .12);

    final leadingIcon = item.leadingIcon;

    return InkWell(
      onTap: () {
        Navigator.of(context, rootNavigator: true).pop();
        item.onTap();
      },
      splashColor: splash,
      highlightColor: highlight,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: leadingIcon != null
                  ? Icon(leadingIcon, size: 20, color: iconColor)
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
                      fontWeight: FontWeight.w500,
                      height: 1.2,
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
            const SizedBox(width: AppSpacing.xs),
            SizedBox(width: 24, child: _trailing(scheme, iconColor)),
          ],
        ),
      ),
    );
  }

  Widget _trailing(ColorScheme scheme, Color iconColor) {
    if (item.checked) {
      return Icon(Icons.check_rounded, size: 20, color: scheme.primary);
    }
    if (item.trailingIcon != null) {
      return Icon(item.trailingIcon, size: 20, color: iconColor);
    }
    return const SizedBox.shrink();
  }
}
