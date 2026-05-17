import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ios_menu_models.dart';

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
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _IosMenuOverlay(
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
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    );
  }
}

class _IosMenuOverlay extends StatelessWidget {
  const _IosMenuOverlay({
    required this.anchor,
    required this.sections,
    required this.animation,
  });

  final Rect anchor;
  final List<IosMenuSection> sections;
  final Animation<double> animation;

  static const double _menuWidth = 260;
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

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          bottom: bottom,
          width: _menuWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight.clamp(120, 600)),
            child: ScaleTransition(
              alignment: Alignment(
                ((anchor.center.dx - left) / _menuWidth) * 2 - 1,
                showAbove ? 1 : -1,
              ),
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: .92)
        : const Color(0xFFF7F7F7).withValues(alpha: .92);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: cardColor,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) _sectionDivider(isDark),
                  ...sections[i].items.map(
                    (item) => _MenuRow(item: item, isDark: isDark),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionDivider(bool isDark) => Container(
    height: 6,
    color: isDark
        ? Colors.white.withValues(alpha: .04)
        : Colors.black.withValues(alpha: .04),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.isDark});
  final IosMenuItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = item.destructive
        ? CupertinoColors.systemRed
        : (isDark ? Colors.white : Colors.black87);
    final iconColor = labelColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context, rootNavigator: true).pop();
          item.onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                child: item.checked
                    ? Icon(Icons.check, size: 16, color: iconColor)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: labelColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: labelColor.withValues(alpha: .55),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(item.trailingIcon, size: 20, color: iconColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
