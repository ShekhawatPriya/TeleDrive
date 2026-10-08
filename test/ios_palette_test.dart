import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/core/theme/ios_palette.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      final label = '${brightness.name}${highContrast ? ' high contrast' : ''}';
      final scheme = iosPalette(
        AppBrand.scheme(brightness, highContrast: highContrast),
        highContrast: highContrast,
      );
      final dark = brightness == Brightness.dark;

      test('$label accent matches UIKit systemBlue/systemRed', () {
        final blue = highContrast
            ? CupertinoColors.systemBlue.highContrastColor
            : CupertinoColors.systemBlue.color;
        final darkBlue = highContrast
            ? CupertinoColors.systemBlue.darkHighContrastColor
            : CupertinoColors.systemBlue.darkColor;
        expect(scheme.primary, dark ? darkBlue : blue);
        expect(scheme.onPrimary, Colors.white);
        if (dark) {
          final red = highContrast
              ? CupertinoColors.systemRed.darkHighContrastColor
              : CupertinoColors.systemRed.darkColor;
          expect(scheme.error, red);
        }
        // Material tonal tint must not wash iOS surfaces.
        expect(scheme.surfaceTint, Colors.transparent);
      });

      test('$label roles keep legible contrast on grouped surfaces', () {
        final floor = highContrast ? 7.0 : 4.5;
        for (final surface in [scheme.surface, scheme.surfaceContainerLow]) {
          expect(
            _contrast(scheme.onSurfaceVariant, surface),
            greaterThanOrEqualTo(floor),
          );
        }
        expect(
          _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.onErrorContainer, scheme.errorContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.onInverseSurface, scheme.inverseSurface),
          greaterThanOrEqualTo(7),
        );
        // Blue doubles as link text; Increase Contrast must strengthen it.
        expect(
          _contrast(scheme.primary, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(highContrast ? 4.5 : 3),
        );
      });
    }
  }

  testWidgets('IosTint resolves to the dark system variant', (tester) async {
    late Color resolved;
    await tester.pumpWidget(
      CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: Builder(
          builder: (context) {
            resolved = CupertinoDynamicColor.resolve(
              IosTint.photoBackup,
              context,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      resolved.toARGB32(),
      CupertinoColors.systemIndigo.darkColor.toARGB32(),
    );
  });
}
