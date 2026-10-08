import 'package:flutter/material.dart';

import 'tokens/app_color.dart';

/// Semantic iOS surfaces. Content is quiet and opaque; chrome owns the glass.
ColorScheme iosPalette(ColorScheme base) {
  final dark = base.brightness == Brightness.dark;
  return base.copyWith(
    primary: dark ? AppAccent.dark : AppAccent.light,
    onPrimary: dark ? const Color(0xFF0E1033) : Colors.white,
    primaryContainer: dark ? const Color(0xFF1B1E3F) : const Color(0xFFECEEFC),
    onPrimaryContainer: dark
        ? const Color(0xFFC9CEFF)
        : const Color(0xFF2E36A0),
    secondaryContainer: dark
        ? const Color(0xFF303034)
        : const Color(0xFFE8E8ED),
    onSecondaryContainer: dark ? Colors.white : const Color(0xFF1C1C1E),
    surface: dark ? const Color(0xFF000000) : const Color(0xFFF5F5F7),
    surfaceContainerLowest: dark ? const Color(0xFF000000) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1C1C1E) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF242426) : const Color(0xFFEFEFF2),
    surfaceContainerHigh: dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE6E6EA),
    surfaceContainerHighest: dark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFDDDDE2),
    onSurface: dark ? Colors.white : Colors.black,
    onSurfaceVariant: dark ? const Color(0xFFB2B2BA) : const Color(0xFF6C707B),
    outlineVariant: dark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),
    error: dark ? const Color(0xFFFF6961) : const Color(0xFFBC252A),
  );
}

/// Graphite for content glyphs that identify a kind of thing (folders, quick
/// actions). Colour is reserved for the single [AppAccent] so the interface
/// reads as quiet and intentional rather than uniformly blue.
Color iosGraphite(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFFA4A6B3)
    : const Color(0xFF565A6B);
