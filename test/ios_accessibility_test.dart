import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/ios_accessibility_controller.dart';
import 'package:flutter_m_fsdk/widgets/adaptive_surface.dart';
import 'package:flutter_m_fsdk/widgets/ios/ios_accessibility.dart';

void main() {
  const channel = MethodChannel('teledrive/accessibility');

  Future<void> notify(WidgetTester tester, bool value) async {
    final completed = Completer<void>();
    tester.binding.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('reduceTransparencyChanged', value),
      ),
      (_) => completed.complete(),
    );
    await completed.future;
  }

  testWidgets('live transparency preferences reach routes and overlays', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (_, child) => IosAccessibility(child: child!),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: AdaptiveSurface(
                    role: GlassRole.navigation,
                    child: SizedBox(height: 80),
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    await notify(tester, false);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);
    await notify(tester, true);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a delayed initial read cannot undo a newer preference notification',
    (tester) async {
      final initial = Completer<bool>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) => initial.future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final controller = IosAccessibilityController();
      final started = controller.start();
      await notify(tester, true);
      initial.complete(false);
      await started;
      expect(controller.reduceTransparency, isTrue);
      controller.dispose();
    },
  );
}
