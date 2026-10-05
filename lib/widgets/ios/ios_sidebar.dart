import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../floating_pill_navigation_bar.dart';

/// iPad navigation shares the shell's destinations and route callbacks.
class IosSidebar extends StatelessWidget {
  const IosSidebar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 256,
      child: ColoredBox(
        color: scheme.surfaceContainerLow,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                child: Text(
                  'TeleDrive',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (var index = 0; index < driveDestinations.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    selected: selectedIndex == index,
                    button: true,
                    label: driveDestinations[index].label,
                    onTap: () => onSelected(index),
                    excludeSemantics: true,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      onPressed: () => onSelected(index),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedIndex == index
                              ? scheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iosDestinationIcon(
                                driveDestinations[index].label,
                                selectedIndex == index,
                              ),
                              size: 24,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                driveDestinations[index].label,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: selectedIndex == index
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                      fontWeight: selectedIndex == index
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
