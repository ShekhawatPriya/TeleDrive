import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../widgets/ios/ios_page.dart';

/// Standard inset selection list: each choice gets a full-width touch target.
class IosAppearancePicker extends StatelessWidget {
  const IosAppearancePicker({
    super.key,
    required this.mode,
    required this.onChanged,
  });
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) => IosGroup(
    title: 'Appearance',
    footer:
        'System automatically matches your iPhone’s Light or Dark appearance.',
    children: [
      // A pick-one list: plain rows and one checkmark, no icon tiles, as in
      // the system's own choice lists.
      for (final option in const [
        (ThemeMode.light, 'Light'),
        (ThemeMode.dark, 'Dark'),
        (ThemeMode.system, 'System'),
      ])
        Semantics(
          selected: mode == option.$1,
          child: IosRow(
            title: option.$2,
            onTap: () => onChanged(option.$1),
            trailing: SizedBox(
              width: 24,
              height: 24,
              child: mode == option.$1
                  ? Icon(
                      CupertinoIcons.check_mark,
                      size: 21,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
          ),
        ),
    ],
  );
}
