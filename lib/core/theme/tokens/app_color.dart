import 'package:flutter/material.dart';

import 'app_elevation.dart';

/// Brand seed and supplemental semantic colors.
///
/// The M3 [ColorScheme] is generated from [AppBrand.seed] via
/// `ColorScheme.fromSeed()` — see `buildTheme()` in `app_theme.dart`.
/// Anything that wants `primary` / `secondary` / `error` / `surface*` should
/// read from the scheme, **not** from this class.
///
/// [AppColors] is reserved for the few semantic accents M3 doesn't model
/// natively (success, warning, info badge tones), plus a small set of
/// deprecated literal accents kept for legacy call sites that haven't been
/// migrated to M3 roles yet.
class AppBrand {
  /// Google Blue — the seed for both light and dark color schemes.
  static const Color seed = Color(0xFF245BDD);

  static ColorScheme scheme(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final dark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      surface: dark ? const Color(0xFF101216) : const Color(0xFFF6F7FA),
      surfaceContainerLowest: dark ? const Color(0xFF0B0D10) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF191C22) : Colors.white,
      surfaceContainer: dark
          ? const Color(0xFF20242C)
          : const Color(0xFFEEF0F5),
      surfaceContainerHigh: dark
          ? const Color(0xFF282D36)
          : const Color(0xFFE7EAF1),
      surfaceContainerHighest: dark
          ? const Color(0xFF323844)
          : const Color(0xFFE0E4ED),
    );
  }
}

class AppColors {
  /// Success / positive state. Not part of the M3 ColorScheme; use sparingly
  /// and prefer `tertiary` from the scheme for non-error accents.
  static const success = Color(0xFF1E8E3E);

  /// Warning / caution. Use for storage-near-limit, optional permissions, etc.
  static const warning = Color(0xFFF9A825);

  /// Informational accent for badges / status pills that want a softer blue
  /// distinct from primary.
  static const info = Color(0xFF1A73E8);

  // ---------------------------------------------------------------------------
  // Legacy shim — accent palette used by feature-icon tints (drive item
  // actions, profile storage chips, file_viewer thumbnails). Slated for
  // migration to ColorScheme.tertiary / secondaryContainer roles screen by
  // screen. Do NOT add new call sites; pull from `Theme.of(context).colorScheme`
  // instead.
  // ---------------------------------------------------------------------------
  @Deprecated('Use Theme.of(context).colorScheme.error')
  static const error = Color(0xFFB3261E);

  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static const link = Color(0xFF1A73E8);

  @Deprecated('Use a darker tone of colorScheme.primary')
  static const linkDeep = Color(0xFF0B57D0);

  @Deprecated('Use AppColors.success')
  static const green = Color(0xFF1E8E3E);

  @Deprecated('Pick a tertiary tone from the scheme')
  static const violet = Color(0xFF7B1FA2);

  @Deprecated('Pick a tertiary tone from the scheme')
  static const cyan = Color(0xFF00ACC1);

  @Deprecated('Pick a tertiary tone from the scheme')
  static const pink = Color(0xFFD81B60);

  @Deprecated('Use AppColors.warning')
  static const amber = Color(0xFFF9A825);

  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant')
  static const mute = Color(0xFF6F6F6F);

  @Deprecated('Use Theme.of(context).colorScheme.onSurface')
  static const body = Color(0xFF424242);
}

/// Legacy shadow presets, kept as a thin shim over [AppElevation.shadowFor]
/// for screens that haven't migrated to theme-default elevation. New code
/// should rely on the `Card` / `Dialog` / `BottomSheet` theme defaults
/// instead.
@Deprecated(
  'Use Card / Dialog / BottomSheet theme defaults, '
  'or AppElevation.shadowFor(level, brightness)',
)
class AppShadows {
  static List<BoxShadow> card(Brightness brightness) =>
      AppElevation.shadowFor(AppElevation.level1, brightness);

  static List<BoxShadow> floating(Brightness brightness) =>
      AppElevation.shadowFor(AppElevation.level3, brightness);
}
