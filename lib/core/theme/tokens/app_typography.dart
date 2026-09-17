import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Platform typography without a network font dependency. Display tracking is
/// tighter than body text; all sizes continue to honor the system text scaler.
TextTheme buildAppTextTheme(ColorScheme scheme) {
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    // Use Flutter's documented system-font proxies, including the optical
    // display face. Private PostScript names can fall back on newer OS builds.
    final native = CupertinoTextThemeData(primaryColor: scheme.primary);
    final body = native.textStyle.copyWith(
      inherit: true,
      textBaseline: TextBaseline.alphabetic,
      color: scheme.onSurface,
      fontWeight: FontWeight.w400,
    );
    final display = native.navLargeTitleTextStyle.copyWith(
      inherit: true,
      textBaseline: TextBaseline.alphabetic,
      color: scheme.onSurface,
    );
    TextStyle text(
      double size,
      double tracking, {
      FontWeight weight = FontWeight.w400,
      Color? color,
    }) => body.copyWith(
      fontSize: size,
      letterSpacing: tracking,
      fontWeight: weight,
      color: color ?? scheme.onSurface,
    );
    return TextTheme(
      displayLarge: display.copyWith(fontSize: 48),
      displayMedium: display.copyWith(fontSize: 40),
      displaySmall: display,
      headlineLarge: display.copyWith(fontSize: 32),
      headlineMedium: display.copyWith(fontSize: 28, letterSpacing: .36),
      headlineSmall: display.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: .07,
      ),
      titleLarge: display.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: .35,
      ),
      titleMedium: body.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text(15, -.23, weight: FontWeight.w600),
      bodyLarge: body,
      bodyMedium: text(15, -.23, color: scheme.onSurfaceVariant),
      bodySmall: text(13, -.08, color: scheme.onSurfaceVariant),
      labelLarge: body.copyWith(fontWeight: FontWeight.w600),
      labelMedium: text(13, -.08, weight: FontWeight.w500),
      labelSmall: text(12, 0, color: scheme.onSurfaceVariant),
    );
  }
  const family = 'Roboto';
  const base = TextTheme();
  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  TextStyle s({
    required double size,
    required double height,
    required FontWeight weight,
    required double letter,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letter,
      color: color ?? onSurface,
    );
  }

  return base.copyWith(
    displayLarge: s(
      size: 48,
      height: 54,
      weight: FontWeight.w700,
      letter: -1.5,
    ),
    displayMedium: s(
      size: 40,
      height: 46,
      weight: FontWeight.w700,
      letter: -1.2,
    ),
    displaySmall: s(size: 34, height: 40, weight: FontWeight.w700, letter: -1),
    headlineLarge: s(
      size: 32,
      height: 38,
      weight: FontWeight.w700,
      letter: -0.8,
    ),
    headlineMedium: s(
      size: 28,
      height: 34,
      weight: FontWeight.w600,
      letter: -0.6,
    ),
    headlineSmall: s(
      size: 24,
      height: 30,
      weight: FontWeight.w600,
      letter: -0.4,
    ),
    titleLarge: s(size: 20, height: 26, weight: FontWeight.w600, letter: -0.3),
    titleMedium: s(size: 16, height: 24, weight: FontWeight.w500, letter: 0),
    titleSmall: s(size: 14, height: 20, weight: FontWeight.w500, letter: 0.10),
    bodyLarge: s(size: 16, height: 24, weight: FontWeight.w400, letter: 0),
    bodyMedium: s(
      size: 14,
      height: 20,
      weight: FontWeight.w400,
      letter: 0,
      color: onSurfaceVariant,
    ),
    bodySmall: s(
      size: 12,
      height: 16,
      weight: FontWeight.w400,
      letter: 0.1,
      color: onSurfaceVariant,
    ),
    labelLarge: s(size: 14, height: 20, weight: FontWeight.w500, letter: 0.10),
    labelMedium: s(size: 12, height: 16, weight: FontWeight.w500, letter: 0),
    labelSmall: s(
      size: 11,
      height: 16,
      weight: FontWeight.w500,
      letter: 0,
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
