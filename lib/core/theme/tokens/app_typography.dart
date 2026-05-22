import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the Material 3 reference type scale using Roboto Flex (with
/// JetBrains Mono kept for `code()`).
///
/// All values match the M3 spec exactly — sizes / line heights / weights /
/// letter spacing — so theme overrides stay minimal and components inherit
/// correct typography from `Theme.of(context).textTheme.<role>`.
TextTheme buildAppTextTheme(ColorScheme scheme) {
  final base = GoogleFonts.robotoFlexTextTheme();
  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  TextStyle s({
    required double size,
    required double height,
    required FontWeight weight,
    required double letter,
    Color? color,
  }) {
    return GoogleFonts.robotoFlex(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letter,
      color: color ?? onSurface,
    );
  }

  return base.copyWith(
    displayLarge: s(
      size: 57,
      height: 64,
      weight: FontWeight.w400,
      letter: -0.25,
    ),
    displayMedium: s(size: 45, height: 52, weight: FontWeight.w400, letter: 0),
    displaySmall: s(size: 36, height: 44, weight: FontWeight.w400, letter: 0),
    headlineLarge: s(size: 32, height: 40, weight: FontWeight.w400, letter: 0),
    headlineMedium: s(size: 28, height: 36, weight: FontWeight.w400, letter: 0),
    headlineSmall: s(size: 24, height: 32, weight: FontWeight.w400, letter: 0),
    titleLarge: s(size: 22, height: 28, weight: FontWeight.w400, letter: 0),
    titleMedium: s(size: 16, height: 24, weight: FontWeight.w500, letter: 0.15),
    titleSmall: s(size: 14, height: 20, weight: FontWeight.w500, letter: 0.10),
    bodyLarge: s(size: 16, height: 24, weight: FontWeight.w400, letter: 0.50),
    bodyMedium: s(
      size: 14,
      height: 20,
      weight: FontWeight.w400,
      letter: 0.25,
      color: onSurfaceVariant,
    ),
    bodySmall: s(
      size: 12,
      height: 16,
      weight: FontWeight.w400,
      letter: 0.40,
      color: onSurfaceVariant,
    ),
    labelLarge: s(size: 14, height: 20, weight: FontWeight.w500, letter: 0.10),
    labelMedium: s(size: 12, height: 16, weight: FontWeight.w500, letter: 0.50),
    labelSmall: s(
      size: 11,
      height: 16,
      weight: FontWeight.w500,
      letter: 0.50,
      color: onSurfaceVariant,
    ),
  );
}

/// Backwards-compatible helper kept for callers that want a monospace style
/// for inline code or hash strings. Uses bundled JetBrains Mono.
extension AppTextThemeExt on TextTheme {
  /// Alias for `bodySmall`, preserved from the previous theme version.
  TextStyle get caption => bodySmall!;

  TextStyle code(Color color) => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.54,
    color: color,
  );
}
