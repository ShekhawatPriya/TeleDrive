import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Semantic iOS surfaces. Content is quiet and opaque; chrome owns the glass.
///
/// UIKit controls (tab bar, toolbars, search field, glass buttons and menus)
/// are tinted with `.systemBlue` and `.systemRed`. Flutter content uses the
/// same system values so a screen never shows two competing accents, and
/// every role is overridden so no Material seed tones leak onto iOS.
/// [highContrast] mirrors UIKit's Increase Contrast variants.
ColorScheme iosPalette(ColorScheme base, {bool highContrast = false}) {
  final dark = base.brightness == Brightness.dark;
  final hc = highContrast;
  Color pick(int light, int darkValue, {int? lightHc, int? darkHc}) => Color(
    dark
        ? (hc ? darkHc ?? darkValue : darkValue)
        : (hc ? lightHc ?? light : light),
  );

  // systemBlue / systemRed, including their accessible variants.
  final blue = pick(
    0xFF007AFF,
    0xFF0A84FF,
    lightHc: 0xFF0040DD,
    darkHc: 0xFF409CFF,
  );
  final red = pick(
    0xFFD70015,
    0xFFFF453A,
    lightHc: 0xFFAD0010,
    darkHc: 0xFFFF6961,
  );
  return base.copyWith(
    primary: blue,
    onPrimary: Colors.white,
    // A tinted fill (systemBlue over the grouped surface) with a deeper blue
    // label, as in UIKit's tinted button style.
    primaryContainer: pick(0xFFE3EEFF, 0xFF132B47, darkHc: 0xFF0F2A4D),
    onPrimaryContainer: pick(
      0xFF0058C7,
      0xFF5EAEFF,
      lightHc: 0xFF003AB8,
      darkHc: 0xFF8CC4FF,
    ),
    // Neutral roles: systemGray and fills rather than seeded blue-greys.
    secondary: pick(
      0xFF8E8E93,
      0xFF8E8E93,
      lightHc: 0xFF6C6C70,
      darkHc: 0xFFAEAEB2,
    ),
    onSecondary: Colors.white,
    secondaryContainer: pick(0xFFE8E8ED, 0xFF303034),
    onSecondaryContainer: dark ? Colors.white : const Color(0xFF1C1C1E),
    tertiary: pick(
      0xFF5856D6,
      0xFF5E5CE6,
      lightHc: 0xFF3634A3,
      darkHc: 0xFF7D7AFF,
    ),
    onTertiary: Colors.white,
    tertiaryContainer: pick(0xFFECECFB, 0xFF22213F),
    onTertiaryContainer: pick(0xFF3634A3, 0xFFB4B3FF),
    error: red,
    onError: Colors.white,
    errorContainer: pick(0xFFFFE6E5, 0xFF3D1414),
    onErrorContainer: pick(
      0xFF9E0012,
      0xFFFF9F98,
      lightHc: 0xFF7A000C,
      darkHc: 0xFFFFC2BD,
    ),
    surface: dark ? const Color(0xFF000000) : const Color(0xFFF2F3F7),
    surfaceContainerLowest: dark ? const Color(0xFF000000) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1C1C1E) : Colors.white,
    surfaceContainer: pick(0xFFEDEDF2, 0xFF242426),
    surfaceContainerHigh: pick(0xFFE5E5EA, 0xFF2C2C2E),
    surfaceContainerHighest: pick(0xFFDCDCE2, 0xFF3A3A3C),
    surfaceBright: pick(0xFFFFFFFF, 0xFF2C2C2E),
    surfaceDim: pick(0xFFE5E5EA, 0xFF000000),
    // Material tonal elevation has no iOS equivalent.
    surfaceTint: Colors.transparent,
    onSurface: dark ? Colors.white : Colors.black,
    // secondaryLabel, kept at or above 4.5:1 on every grouped surface.
    onSurfaceVariant: pick(
      0xFF6C6C72,
      0xFFAEAEB4,
      lightHc: 0xFF3C3C43,
      darkHc: 0xFFD1D1D6,
    ),
    outline: pick(
      0xFFAEAEB2,
      0xFF636366,
      lightHc: 0xFF6C6C70,
      darkHc: 0xFF98989E,
    ),
    outlineVariant: pick(
      0xFFD1D1D6,
      0xFF38383A,
      lightHc: 0xFF8E8E93,
      darkHc: 0xFF636366,
    ),
    inverseSurface: pick(0xFF1C1C1E, 0xFFF2F2F7),
    onInverseSurface: dark ? Colors.black : Colors.white,
    inversePrimary: pick(0xFF0A84FF, 0xFF007AFF),
    shadow: Colors.black,
    scrim: Colors.black,
  );
}

/// One system tint per destination or media kind, so a symbol keeps its
/// colour (and meaning) on every page it appears. Resolve against the
/// current context; `IosRow` does this for its icon tiles.
abstract final class IosTint {
  static const telegramDrive = CupertinoColors.systemBlue;
  static const uploads = CupertinoColors.systemBlue;
  static const photoBackup = CupertinoColors.systemIndigo;
  static const storage = CupertinoColors.systemOrange;
  static const freeUpSpace = CupertinoColors.systemGreen;
  static const privacy = CupertinoColors.systemBlue;
  static const session = CupertinoColors.systemGreen;
  static const notifications = CupertinoColors.systemRed;
  static const help = CupertinoColors.systemOrange;
  static const neutral = CupertinoColors.systemGrey;

  static const photos = CupertinoColors.systemPink;
  static const videos = CupertinoColors.systemOrange;
  static const documents = CupertinoColors.systemBlue;
  static const audio = CupertinoColors.systemPurple;
  static const other = CupertinoColors.systemGrey;
}
