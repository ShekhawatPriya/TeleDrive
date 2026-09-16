import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/widgets/adaptive_surface.dart';

void main() {
  testWidgets('iOS navigation transmits backdrop color with reduced motion', (
    tester,
  ) async {
    Future<List<int>> sample(
      Color background, {
      bool highContrast = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: MediaQuery(
            data: MediaQueryData(
              highContrast: highContrast,
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: const ValueKey('sample'),
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: background)),
                    const Center(
                      child: SizedBox(
                        width: 260,
                        height: 80,
                        child: AdaptiveSurface(
                          role: GlassRole.navigation,
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('sample')),
      );
      return tester
          .runAsync(() async {
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            final offset =
                ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
            final pixel = bytes.sublist(offset, offset + 3);
            image.dispose();
            return pixel;
          })
          .then((pixel) => pixel!);
    }

    final warm = await sample(const Color(0xFFCC4433));
    final cool = await sample(const Color(0xFF2255CC));
    expect((warm[0] - cool[0]).abs(), greaterThan(100));
    expect((warm[2] - cool[2]).abs(), greaterThan(100));
    expect(find.byType(BackdropFilter), findsOneWidget);
    final solidWarm = await sample(Colors.red, highContrast: true);
    final solidCool = await sample(Colors.blue, highContrast: true);
    expect(solidWarm, solidCool);
    expect(find.byType(BackdropFilter), findsNothing);
  });
  testWidgets('Android navigation remains opaque without backdrop blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const AdaptiveSurface(
          role: GlassRole.navigation,
          child: SizedBox(height: 80),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
