import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/navigation/root_navigator.dart';
import 'package:flutter_m_fsdk/widgets/fab_anchor.dart';
import 'package:flutter_m_fsdk/widgets/premium_toast.dart';

void main() {
  setUpAll(() async {
    for (final family in [
      'Inter',
      'Roboto',
      '.SF Pro Text',
      '.SF Pro Display',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDown(() {
    dismissPremiumToast();
    fabAnchor.value = null;
  });

  Future<void> host(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.iOS,
    Brightness brightness = Brightness.dark,
    double scale = 1,
    bool contrast = false,
    bool showFab = true,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fabKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview'),
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(AppBrand.scheme(brightness)).copyWith(
            platform: platform,
            textTheme: buildTheme(
              AppBrand.scheme(brightness),
            ).textTheme.apply(fontFamily: 'Inter'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              highContrast: contrast,
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Drive')),
            body: ListView(
              children: List.generate(
                8,
                (i) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text('Travel document ${i + 1}'),
                  subtitle: const Text('PDF · 291 KB'),
                ),
              ),
            ),
            floatingActionButton: FabAnchorPublisher(
              fabKey: fabKey,
              child: showFab
                  ? FloatingActionButton(
                      key: fabKey,
                      onPressed: () {},
                      child: const Icon(Icons.add),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('authorization entry cancels visible and queued confirmations', (
    tester,
  ) async {
    await host(tester);
    showAppPremiumToast(
      message: 'Added Sree.',
      icon: Icons.person,
      afterNavigation: true,
    );
    dismissPremiumToast();
    await tester.pump();
    expect(find.text('Added Sree.'), findsNothing);
    showAppPremiumToast(message: 'Switched account.', icon: Icons.person);
    await tester.pump();
    expect(find.text('Switched account.'), findsOneWidget);
    dismissPremiumToast();
    await tester.pump();
    expect(find.text('Switched account.'), findsNothing);
  });

  testWidgets('navigation guard rejects stale confirmation', (tester) async {
    await host(tester);
    var ready = true;
    showAppPremiumToast(
      message: 'Switched account.',
      icon: Icons.person,
      afterNavigation: true,
      canShow: () => ready,
    );
    ready = false;
    await tester.pump();
    expect(find.text('Switched account.'), findsNothing);
  });

  testWidgets('without Add banner uses full width at the same row height', (
    tester,
  ) async {
    await host(tester);
    showAppPremiumToast(message: 'Account switched.', icon: Icons.person);
    await tester.pump();
    final card = find.byKey(const ValueKey('premium-toast-card'));
    final bottom = tester.getBottomLeft(card).dy;
    await host(tester, showFab: false);
    await tester.pump();
    expect(tester.getBottomLeft(card).dy, bottom);
    expect(tester.getTopLeft(card).dx, 16);
    expect(tester.getTopRight(card).dx, 304);
    expect(fabAnchor.value?.reservedWidth, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(fabAnchor.value, isNull);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      for (final accessible in [false, true]) {
        testWidgets(
          'banner ${platform.name} ${brightness.name} accessible=$accessible',
          (tester) async {
            await host(
              tester,
              platform: platform,
              brightness: brightness,
              scale: accessible ? 2 : 1,
              contrast: accessible,
            );

            const message = 'Switched to Priya Shekhawat.';
            showAppPremiumToast(
              message: message,
              avatarUser: const AuthUser(
                userId: 1,
                telegramId: 1,
                firstName: 'Priya',
                lastName: 'Shekhawat',
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
            final text = tester.widget<Text>(find.text(message));
            expect(text.maxLines, isNull);
            expect(
              tester
                  .getBottomLeft(
                    find.byKey(const ValueKey('premium-toast-card')),
                  )
                  .dy,
              tester.getBottomLeft(find.byType(FloatingActionButton)).dy,
            );
            expect(
              tester
                  .getTopRight(find.byKey(const ValueKey('premium-toast-card')))
                  .dx,
              tester.getTopLeft(find.byType(FloatingActionButton)).dx - 12,
            );
            expect(
              find.byType(BackdropFilter),
              platform == TargetPlatform.iOS && !accessible
                  ? findsOneWidget
                  : findsNothing,
            );
            if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
              await tester.runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('preview')),
                );
                final image = await boundary.toImage(pixelRatio: 2);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/modernization/account-banner-${platform.name}-${brightness.name}${accessible ? '-accessible' : ''}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(data!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pump(const Duration(seconds: 4));
            expect(find.text(message), findsNothing);
          },
        );
      }
    }
  }
}
