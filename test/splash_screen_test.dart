import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/core/theme/ios_palette.dart';
import 'package:flutter_m_fsdk/shared/splash_screen.dart';
import 'package:flutter_m_fsdk/shared/launch_mark.dart';

void main() {
  testWidgets('saved app appearance does not recolor the native handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(AppBrand.scheme(Brightness.light)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(platformBrightness: Brightness.dark),
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppBrand.scheme(Brightness.dark).surface,
    );
    expect(
      tester.widget<LaunchMark>(find.byType(LaunchMark)).color,
      AppBrand.scheme(Brightness.dark).onSurface,
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final accessible in [false, true]) {
        testWidgets(
          'splash ${platform.name} ${brightness.name} accessible=$accessible',
          (tester) async {
            tester.view.physicalSize = accessible
                ? const Size(320, 568)
                : const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            debugDefaultTargetPlatformOverride = platform;
            final theme = buildTheme(
              AppBrand.scheme(brightness, highContrast: accessible),
            ).copyWith(platform: platform);
            debugDefaultTargetPlatformOverride = null;
            final key = GlobalKey();
            final semantics = tester.ensureSemantics();

            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(accessible ? 2 : 1),
                    disableAnimations: accessible,
                    highContrast: accessible,
                    platformBrightness: brightness,
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(key: key, child: const SplashScreen()),
              ),
            );
            expect(tester.takeException(), isNull);
            expect(
              find.bySemanticsLabel('TeleDrive. Opening your drive'),
              findsOneWidget,
            );
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(tester.getSize(find.byType(LaunchMark)), const Size(96, 96));
            expect(
              tester.getCenter(find.byType(LaunchMark)),
              tester.view.physicalSize.center(Offset.zero),
            );
            expect(find.byType(Image), findsNothing);
            // First-frame capture: no pumpAndSettle or asynchronous image decode.
            final mark = tester.widget<LaunchMark>(find.byType(LaunchMark));
            final nativeScheme = platform == TargetPlatform.iOS
                ? iosPalette(AppBrand.scheme(brightness))
                : AppBrand.scheme(brightness);
            expect(mark.color, nativeScheme.onSurface);
            final foreground = mark.color.computeLuminance();
            final background = nativeScheme.surface.computeLuminance();
            final contrast = foreground > background
                ? (foreground + .05) / (background + .05)
                : (background + .05) / (foreground + .05);
            expect(contrast, greaterThan(7));
            semantics.dispose();
            if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final capture = await boundary.toImage();
                final bytes = await capture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/modernization/splash-${platform.name}-${brightness.name}${accessible ? '-accessible' : ''}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                capture.dispose();
              });
            }
          },
        );
      }
    }
  }
}
