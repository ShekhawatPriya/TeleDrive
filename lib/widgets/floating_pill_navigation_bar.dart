import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingPillNavigationBar extends StatelessWidget {
  const FloatingPillNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    // Theme-correct dynamic Material 3 colors with elegant opacity
    final Color pillBgColor = scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.82 : 0.90);
    final Color activeBgColor = scheme.secondaryContainer;
    final Color activeContentColor = scheme.onSecondaryContainer;
    final Color inactiveTextColor = scheme.onSurfaceVariant.withValues(alpha: 0.85);

    final bool isLeftActive = selectedIndex >= 0 && selectedIndex < 3;

    // Double-layered premium shadow system for realistic depth projection
    final List<BoxShadow> premiumShadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];

    // Hardware-refined outline border side
    final BorderSide microBorderSide = BorderSide(
      color: isDark
          ? scheme.outlineVariant.withValues(alpha: 0.18)
          : scheme.outline.withValues(alpha: 0.08),
      width: 1.0,
    );

    // Premium cubic bezier decelerate animation curve
    const Curve transitionCurve = Cubic(0.05, 0.7, 0.1, 1.0);

    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final double barHeight = 74.0 + bottomPadding;

    return SizedBox(
      height: barHeight,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Left Pill (Drive, Photos, Starred) - Tighter, Compact Center Design
                Container(
                  width: 276,
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: premiumShadows,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        height: 62,
                        decoration: ShapeDecoration(
                          shape: StadiumBorder(side: microBorderSide),
                          color: pillBgColor,
                        ),
                        child: Stack(
                          children: [
                            // Sliding Active Indicator Bubble
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 280),
                              curve: transitionCurve,
                              alignment: Alignment(-1.0 + (isLeftActive ? selectedIndex * 1.0 : 0.0), 0.0),
                              child: FractionallySizedBox(
                                widthFactor: 1 / 3,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  scale: isLeftActive ? 1.0 : 0.0,
                                  curve: Curves.easeInOut,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: isLeftActive ? 1.0 : 0.0,
                                    child: Container(
                                      margin: const EdgeInsets.all(5),
                                      decoration: ShapeDecoration(
                                        shape: const StadiumBorder(),
                                        color: activeBgColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Tab Items Row
                            Row(
                              children: [
                                _TabItem(
                                  label: 'Drive',
                                  activeIcon: Icons.folder,
                                  inactiveIcon: Icons.folder_outlined,
                                  isActive: selectedIndex == 0,
                                  activeColor: activeContentColor,
                                  inactiveColor: inactiveTextColor,
                                  onTap: () => onDestinationSelected(0),
                                ),
                                _TabItem(
                                  label: 'Photos',
                                  activeIcon: Icons.photo_library,
                                  inactiveIcon: Icons.photo_library_outlined,
                                  isActive: selectedIndex == 1,
                                  activeColor: activeContentColor,
                                  inactiveColor: inactiveTextColor,
                                  onTap: () => onDestinationSelected(1),
                                ),
                                _TabItem(
                                  label: 'Starred',
                                  activeIcon: Icons.star_rounded,
                                  inactiveIcon: Icons.star_border_rounded,
                                  isActive: selectedIndex == 2,
                                  activeColor: activeContentColor,
                                  inactiveColor: inactiveTextColor,
                                  onTap: () => onDestinationSelected(2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Right Detached Shared Pill (Perfect Circle, Icon Only)
                Container(
                  width: 62,
                  height: 62,
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: premiumShadows,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => onDestinationSelected(3),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: transitionCurve,
                            width: 62,
                            height: 62,
                            decoration: ShapeDecoration(
                              shape: StadiumBorder(side: microBorderSide),
                              color: selectedIndex == 3
                                  ? activeBgColor.withValues(alpha: isDark ? 0.85 : 0.95)
                                  : pillBgColor,
                            ),
                            child: Center(
                              child: Icon(
                                selectedIndex == 3 ? Icons.group : Icons.group_outlined,
                                color: selectedIndex == 3 ? activeContentColor : inactiveTextColor,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? activeColor : inactiveColor,
                size: 19,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : inactiveColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
