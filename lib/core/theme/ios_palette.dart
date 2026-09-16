import 'package:flutter/material.dart';

/// Semantic iOS surfaces. Content is quiet and opaque; chrome owns the glass.
ColorScheme iosPalette(ColorScheme base) {
  final dark = base.brightness == Brightness.dark;
  return base.copyWith(
    primary: dark ? const Color(0xFF5AA9FF) : const Color(0xFF0068D9),
    onPrimary: dark ? const Color(0xFF001C3B) : Colors.white,
    primaryContainer: dark ? const Color(0xFF122D48) : const Color(0xFFE4F0FF),
    onPrimaryContainer: dark
        ? const Color(0xFFACD3FF)
        : const Color(0xFF004B9B),
    secondaryContainer: dark
        ? const Color(0xFF303034)
        : const Color(0xFFE8E8ED),
    onSecondaryContainer: dark ? Colors.white : const Color(0xFF1C1C1E),
    surface: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
    surfaceContainerLowest: dark ? const Color(0xFF000000) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1C1C1E) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF242426) : const Color(0xFFEDEDF2),
    surfaceContainerHigh: dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA),
    surfaceContainerHighest: dark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFDCDCE2),
    onSurface: dark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E),
    onSurfaceVariant: dark ? const Color(0xFFB2B2BA) : const Color(0xFF63636B),
    outlineVariant: dark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),
    error: dark ? const Color(0xFFFF6961) : const Color(0xFFBC252A),
  );
}
