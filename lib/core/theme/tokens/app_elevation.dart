import 'package:flutter/material.dart';

/// Material 3 elevation levels (in dp) and the corresponding shadow stacks.
///
/// M3 uses both **tonal elevation** (a tint applied to the surface color from
/// the primary palette) and **shadow elevation**. Components in this app rely
/// on Flutter's built-in `surfaceTintColor` for the tint; [shadowFor] returns
/// a hand-tuned shadow list that matches the M3 reference for each level.
class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;
  static const double level4 = 8;
  static const double level5 = 12;

  /// Returns the M3 shadow stack for a given elevation level, scaled by
  /// brightness. Light mode uses two-layer ambient + key shadows; dark mode
  /// uses a single deeper key shadow because shadows are less visible against
  /// dark surfaces.
  static List<BoxShadow> shadowFor(double level, Brightness brightness) {
    if (level <= 0) return const [];
    final dark = brightness == Brightness.dark;
    final ambientAlpha = dark ? 0x4d : 0x14;
    final keyAlpha = dark ? 0x80 : 0x33;

    final keyOffsetY = level.clamp(1, 12).toDouble();
    final keyBlur = (level * 2).clamp(2, 24).toDouble();
    final ambientBlur = (level * 1.5).clamp(1, 16).toDouble();

    return [
      BoxShadow(
        color: Color(ambientAlpha << 24),
        offset: const Offset(0, 1),
        blurRadius: ambientBlur,
      ),
      BoxShadow(
        color: Color(keyAlpha << 24),
        offset: Offset(0, keyOffsetY / 2),
        blurRadius: keyBlur,
        spreadRadius: -level / 4,
      ),
    ];
  }
}
