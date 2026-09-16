import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const driveDestinations = <({String label, IconData icon, IconData selected})>[
  (label: 'Drive', icon: Icons.folder_outlined, selected: Icons.folder_rounded),
  (
    label: 'Photos',
    icon: Icons.photo_library_outlined,
    selected: Icons.photo_library_rounded,
  ),
  (
    label: 'Starred',
    icon: Icons.star_outline_rounded,
    selected: Icons.star_rounded,
  ),
  (label: 'Shared', icon: Icons.link_rounded, selected: Icons.link_rounded),
];

/// Platform navigation that adapts to width and the user's text size.
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
    final scheme = theme.colorScheme;
    if (theme.platform != TargetPlatform.iOS) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final item in driveDestinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selected),
              label: item.label,
            ),
        ],
      );
    }
    final accessible =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final bar = Material(
      color: scheme.surfaceContainerLow.withValues(alpha: accessible ? 1 : .94),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (var index = 0; index < driveDestinations.length; index++)
              Expanded(
                child: _TabButton(
                  item: driveDestinations[index],
                  selected: index == selectedIndex,
                  onPressed: () => onDestinationSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: .06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: accessible
                  ? bar
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: bar,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });
  final ({String label, IconData icon, IconData selected}) item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      onTap: onPressed,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: .09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.selected : item.icon,
                  size: 23,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
