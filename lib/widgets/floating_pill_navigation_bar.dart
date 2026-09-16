import 'package:flutter/cupertino.dart';
import 'adaptive_surface.dart';
import 'native_tab_bar.dart';
import 'package:flutter/services.dart';
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
    final ios = theme.platform == TargetPlatform.iOS;
    if (ios)
      return NativeTabBar(
        selectedIndex: selectedIndex,
        onSelected: onDestinationSelected,
      );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AdaptiveSurface(
            role: GlassRole.navigation,
            radius: ios ? 32 : 30,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Stack(
                children: [
                  if (ios)
                    Positioned.fill(
                      child: AnimatedAlign(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          -1 +
                              selectedIndex *
                                  2 /
                                  (driveDestinations.length - 1),
                          0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 1 / driveDestinations.length,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? .13
                                    : .065,
                              ),
                              borderRadius: BorderRadius.circular(27),
                              border: Border.all(
                                color: theme.colorScheme.surfaceContainerLow
                                    .withValues(alpha: .22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (
                        var index = 0;
                        index < driveDestinations.length;
                        index++
                      )
                        Expanded(
                          child: _TabButton(
                            item: driveDestinations[index],
                            selected: index == selectedIndex,
                            onPressed: () {
                              if (index != selectedIndex)
                                HapticFeedback.selectionClick();
                              onDestinationSelected(index);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
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
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final color = selected
        ? (ios ? scheme.primary : scheme.onSecondaryContainer)
        : (ios
              ? scheme.onSurface.withValues(alpha: .82)
              : scheme.onSurfaceVariant);
    final content = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: selected
            ? (ios ? Colors.transparent : scheme.secondaryContainer)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ios
                  ? _iosIcon(item.label, selected)
                  : (selected ? item.selected : item.icon),
              size: 24,
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
    );
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      onTap: onPressed,
      excludeSemantics: true,
      child: ios
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onPressed,
              child: content,
            )
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onPressed, child: content),
            ),
    );
  }
}

IconData _iosIcon(String label, bool selected) => switch (label) {
  'Drive' => selected ? CupertinoIcons.folder_fill : CupertinoIcons.folder,
  'Photos' =>
    selected
        ? CupertinoIcons.photo_fill_on_rectangle_fill
        : CupertinoIcons.photo_on_rectangle,
  'Starred' => selected ? CupertinoIcons.star_fill : CupertinoIcons.star,
  _ => CupertinoIcons.link,
};
