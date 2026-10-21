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
import 'package:flutter_m_fsdk/widgets/profile_avatar.dart';

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
    double width = 320,
    double height = 700,
    EdgeInsets safeArea = EdgeInsets.zero,
    bool header = false,
    bool headerVisible = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
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
              padding: safeArea,
              viewPadding: safeArea,
            ),
            child: child!,
          ),
          home: Scaffold(
            appBar: header ? null : AppBar(title: const Text('Drive')),
            body: header
                ? _IosDriveFixture(visible: headerVisible)
                : ListView(
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

  const priya = AuthUser(
    userId: 1,
    telegramId: 1,
    firstName: 'Priya',
    lastName: 'Shekhawat',
  );
  const sree = AuthUser(userId: 2, telegramId: 2, firstName: 'Sree');
  const longName = AuthUser(
    userId: 3,
    telegramId: 3,
    firstName: 'Alexandria',
    lastName: 'Montgomery-Featherstonehaugh',
  );
  String displayName(AuthUser user) =>
      user.firstName +
      (user.lastName?.isNotEmpty == true ? ' ${user.lastName}' : '');
  final card = find.byKey(const ValueKey('premium-toast-card'));

  Future<void> writePreview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/modernization/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<Rect> showAccount(
    WidgetTester tester,
    AuthUser user, {
    String? preview,
    void Function()? inspect,
  }) async {
    showAppPremiumToast(
      headline: displayName(user),
      message: 'Switched account',
      avatarUser: user,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    if (preview != null) await writePreview(tester, preview);
    inspect?.call();
    final rect = tester.getRect(card);
    dismissPremiumToast();
    await tester.pump();
    return rect;
  }

  group('iOS', () {
    const phone = EdgeInsets.only(top: 59, bottom: 34);
    final controls = find.byKey(const ValueKey('header-controls'));

    Future<void> phoneHost(
      WidgetTester tester, {
      Brightness brightness = Brightness.dark,
      double width = 393,
      double scale = 1,
    }) => host(
      tester,
      width: width,
      height: 852,
      safeArea: phone,
      header: true,
      brightness: brightness,
      scale: scale,
    );

    for (final (name, user) in [
      ('sree', sree),
      ('priya', priya),
      ('long', longName),
    ]) {
      testWidgets('$name sits in the header row beside the controls', (
        tester,
      ) async {
        await phoneHost(tester);
        final row = tester.getRect(controls);
        final rect = await showAccount(
          tester,
          user,
          preview: 'account-banner-iOS-header-$name',
          inspect: () {
            final pill = tester.getRect(card);
            final avatar = tester.getRect(find.byType(ProfileAvatar).last);
            // Concentric avatar, leading text and a hugging trailing inset.
            expect(avatar.left - pill.left, 6);
            expect(avatar.size, const Size(32, 32));
            final headline = tester.getRect(find.text(displayName(user)));
            expect(headline.left - avatar.right, 10);
            if (user != longName) {
              final status = tester.getRect(find.text('Switched account'));
              final textRight = headline.right > status.right
                  ? headline.right
                  : status.right;
              expect(pill.right - textRight, closeTo(16, .5));
              expect(avatar.center.dy, closeTo(pill.center.dy, .01));
            }
          },
        );
        // Shares the controls' row, the title's gutter and their 8-point gap.
        expect(rect.top, row.top);
        expect(rect.left, 20);
        expect(rect.right, lessThanOrEqualTo(row.left - 8));
        expect(rect.overlaps(row), isFalse);
        if (user == longName) {
          // Wraps, shrinking to its longest line, inside the free span.
          expect(rect.height, greaterThan(44));
        } else {
          expect(rect.height, 44);
        }
      });
    }

    testWidgets('light appearance matches', (tester) async {
      await phoneHost(tester, brightness: Brightness.light);
      final rect = await showAccount(
        tester,
        sree,
        preview: 'account-banner-iOS-header-sree-light',
      );
      expect(rect.height, 44);
    });

    testWidgets('large text takes its own row under the controls', (
      tester,
    ) async {
      await phoneHost(tester, width: 320, scale: 2);
      final row = tester.getRect(controls);
      final rect = await showAccount(
        tester,
        priya,
        preview: 'account-banner-iOS-header-accessible',
      );
      expect(rect.top, row.bottom + 8);
      expect(rect.left, 20);
      expect(rect.right, lessThanOrEqualTo(300));
    });

    testWidgets('hidden tab headers are ignored', (tester) async {
      await host(
        tester,
        width: 393,
        height: 852,
        safeArea: phone,
        header: true,
        headerVisible: false,
      );
      final rect = await showAccount(tester, priya);
      expect(rect.center.dx, closeTo(196.5, .01));
      expect(rect.top, 63);
    });

    testWidgets('without a header it is centred under the Dynamic Island', (
      tester,
    ) async {
      await host(tester, width: 390, safeArea: phone);
      final rect = await showAccount(
        tester,
        priya,
        preview: 'account-banner-iOS-no-header',
      );
      expect(rect.center.dx, closeTo(195, .01));
      expect(rect.top, 63);
      expect(rect.height, 44);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(rect.overlaps(fab), isFalse);
    });

    testWidgets('swipe up dismisses', (tester) async {
      await host(tester, width: 390, safeArea: phone);
      showAppPremiumToast(
        headline: 'Sree',
        message: 'Switched account',
        avatarUser: sree,
      );
      await tester.pump();
      await tester.drag(card, const Offset(0, -40));
      await tester.pump();
      expect(card, findsNothing);
    });
  });

  testWidgets('Android: without Add banner uses full width at row height', (
    tester,
  ) async {
    await host(tester, platform: TargetPlatform.android);
    showAppPremiumToast(message: 'Account switched.', icon: Icons.person);
    await tester.pump();
    final bottom = tester.getBottomLeft(card).dy;
    await host(tester, platform: TargetPlatform.android, showFab: false);
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

            showAppPremiumToast(
              headline: 'Priya Shekhawat',
              message: 'Switched account',
              avatarUser: priya,
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
            for (final value in ['Priya Shekhawat', 'Switched account']) {
              expect(tester.widget<Text>(find.text(value)).maxLines, isNull);
            }
            expect(
              tester.getSemantics(card).label,
              'Priya Shekhawat. Switched account',
            );
            final fab = tester.getRect(find.byType(FloatingActionButton));
            if (platform == TargetPlatform.iOS) {
              expect(tester.getCenter(card).dx, closeTo(160, .01));
              expect(tester.getTopLeft(card).dy, 20);
              expect(tester.getRect(card).overlaps(fab), isFalse);
            } else {
              expect(tester.getBottomLeft(card).dy, fab.bottom);
              expect(tester.getTopRight(card).dx, fab.left - 12);
            }
            expect(
              find.byType(BackdropFilter),
              platform == TargetPlatform.iOS && !accessible
                  ? findsOneWidget
                  : findsNothing,
            );
            await writePreview(
              tester,
              'account-banner-${platform.name}-${brightness.name}${accessible ? '-accessible' : ''}',
            );
            await tester.pump(const Duration(seconds: 4));
            expect(find.text('Priya Shekhawat'), findsNothing);
          },
        );
      }
    }
  }
}

/// A stand-in for the iOS Drive header: the 44-point overflow capsule and
/// account avatar 16 points from the edge, the large title and search field.
class _IosDriveFixture extends StatelessWidget {
  const _IosDriveFixture({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas = dark ? Colors.black : const Color(0xFFF2F2F7);
    final control = dark ? const Color(0xFF2C2C2E) : Colors.white;
    final top = MediaQuery.paddingOf(context).top;
    final controls = Row(
      key: const ValueKey('header-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: control, shape: BoxShape.circle),
          child: Icon(Icons.more_horiz, color: scheme.onSurface),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: ProfileAvatar(
              user: const AuthUser(userId: 9, telegramId: 9, firstName: 'S'),
              size: 40,
            ),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: canvas,
      child: ListView(
        padding: EdgeInsets.only(top: top + 4),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TickerMode(
                enabled: visible,
                child: PremiumToastHeaderAnchor(child: controls),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Text(
              'Drive',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: control,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search files and folders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < 6; i++)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text('Travel document ${i + 1}'),
              subtitle: const Text('PDF · 291 KB'),
            ),
        ],
      ),
    );
  }
}
