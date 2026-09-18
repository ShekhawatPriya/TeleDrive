import 'package:flutter/material.dart';

/// Accessible appearance choices using the same connected rows as Settings.
class ThemePickerCards extends StatelessWidget {
  const ThemePickerCards({
    required this.mode,
    required this.onChanged,
    super.key,
  });
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const choices = [
      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
    ];
    return Column(
      children: [
        for (var i = 0; i < choices.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: Semantics(
              selected: mode == choices[i].$1,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: mode == choices[i].$1
                    ? scheme.primaryContainer
                    : scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 24 : 4),
                    bottom: Radius.circular(i == choices.length - 1 ? 24 : 4),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  minTileHeight: 64,
                  leading: Icon(choices[i].$3),
                  title: Text(choices[i].$2),
                  textColor: mode == choices[i].$1
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  iconColor: mode == choices[i].$1
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  trailing: Icon(
                    mode == choices[i].$1
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  onTap: () => onChanged(choices[i].$1),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
