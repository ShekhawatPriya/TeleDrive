import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/widgets/ios/ios_page.dart';

/// Settings-style page contract: hero-led pages reveal the inline title only
/// once the hero title scrolls under the bar, the bar is transparent at rest,
/// and groups/rows follow the iOS 26 Settings geometry.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.light,
    double width = 402,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final theme = buildTheme(AppBrand.scheme(brightness));
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: const ValueKey('preview'),
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 62, bottom: 34),
                textScaler: TextScaler.linear(scale),
              ),
              child: page,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/modernization/ios-settings-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  double barTitleOpacity(WidgetTester tester, String title) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.descendant(
                of: find.byType(IosNavigationBar),
                matching: find.text(title),
              ),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  /// The opacity of the bar's fill, whichever bar the page uses.
  double barBackgroundOpacity(WidgetTester tester) => tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .firstWhere((widget) => widget.child is ColoredBox)
      .opacity;

  Widget heroPage({VoidCallback? onLearnMore}) => IosPage(
    title: 'General',
    compact: true,
    children: [
      IosSettingsIntro(
        icon: CupertinoIcons.gear_alt_fill,
        color: CupertinoColors.systemGrey,
        title: 'General',
        description: 'Manage your overall setup and preferences.',
        onLearnMore: onLearnMore,
      ),
      IosGroup(
        title: 'Device',
        footer: 'Details about this iPhone.',
        children: [
          IosRow(
            title: 'About',
            icon: CupertinoIcons.device_phone_portrait,
            onTap: () {},
          ),
          IosRow(title: 'Software Update', value: 'Up to date', onTap: () {}),
          const IosRow(title: 'Name', value: 'iPhone'),
        ],
      ),
      for (var i = 0; i < 6; i++)
        IosGroup(
          children: [
            for (var j = 0; j < 3; j++)
              IosRow(title: 'Row $i.$j', onTap: () {}),
          ],
        ),
    ],
  );

  for (final brightness in Brightness.values) {
    testWidgets('hero page hides the bar title until the hero scrolls away '
        '${brightness.name}', (tester) async {
      await pump(tester, heroPage(), brightness: brightness);
      await preview(tester, 'hero-${brightness.name}-top');
      expect(barTitleOpacity(tester, 'General'), 0);
      expect(barBackgroundOpacity(tester), 0);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
      await tester.pumpAndSettle();
      // The hero title is still visible below the bar.
      expect(barTitleOpacity(tester, 'General'), 0);
      expect(barBackgroundOpacity(tester), 1);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(barTitleOpacity(tester, 'General'), 1);
      await preview(tester, 'hero-${brightness.name}-scrolled');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(barTitleOpacity(tester, 'General'), 0);
      expect(barBackgroundOpacity(tester), 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a page without a hero shows its inline title immediately', (
    tester,
  ) async {
    await pump(
      tester,
      IosPage(
        title: 'Appearance',
        compact: true,
        children: [
          IosGroup(
            title: 'Appearance',
            children: [IosRow(title: 'Text Size', onTap: () {})],
          ),
        ],
      ),
    );
    expect(barTitleOpacity(tester, 'Appearance'), 1);
    final bar = tester.getRect(find.byType(IosNavigationBar));
    expect(bar.top, 0);
    expect(bar.height, 62 + IosPageMetrics.barHeight);
    // Back sits at the 16-point margin, vertically centred in the 44-point bar.
    final back = tester.getRect(find.bySemanticsLabel('Back').first);
    expect(back.left, IosPageMetrics.margin);
    expect(back.center.dy, 62 + 22);
    // The first group starts 20 points below the bar.
    final header = tester.getRect(find.text('Appearance').last);
    expect(header.top, bar.bottom + IosPageMetrics.contentTop);
  });

  testWidgets('rows meet the Settings height and separators follow titles', (
    tester,
  ) async {
    await pump(tester, heroPage());
    for (final title in ['About', 'Software Update', 'Name']) {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byType(IosRow),
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(52));
    }
    final card = tester.getRect(find.byType(ClipRSuperellipse).at(1));
    expect(tester.getRect(find.text('About')).left - card.left, 54);
    expect(tester.getRect(find.text('Name')).left - card.left, 16);
    // The section header sits outside the card, aligned with row titles.
    final header = tester.getRect(find.text('Device'));
    expect(header.bottom, lessThan(card.top));
    expect(header.left - card.left, 16);
    // The footnote sits below the card.
    expect(
      tester.getRect(find.text('Details about this iPhone.')).top,
      greaterThan(card.bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Learn more opens its destination', (tester) async {
    var opened = 0;
    await pump(tester, heroPage(onLearnMore: () => opened++));
    await tester.tapOnText(find.textRange.ofSubstring('Learn more…'));
    expect(opened, 1);
  });

  testWidgets('hero page fits 320 points at 200% text', (tester) async {
    await pump(tester, heroPage(onLearnMore: () {}), width: 320, scale: 2);
    await preview(tester, 'hero-large-text');
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(barTitleOpacity(tester, 'General'), 1);
    expect(tester.takeException(), isNull);
  });

  Widget browsePage({required Widget bar, bool hero = false}) => Scaffold(
    backgroundColor: Colors.white,
    body: IosHeroScope(
      child: CustomScrollView(
        slivers: [
          bar,
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList.list(
              children: [
                if (hero)
                  const IosSettingsIntro(
                    icon: CupertinoIcons.archivebox_fill,
                    color: CupertinoColors.systemBlue,
                    title: 'Archive',
                    description: 'These items are hidden from the main drive.',
                    fill: Color(0xFFF2F2F7),
                  ),
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('Item $i')),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget glass(String label) => SizedBox.square(
    key: ValueKey(label),
    dimension: 44,
    child: Semantics(label: label, child: const Placeholder()),
  );

  for (final brightness in Brightness.values) {
    testWidgets('root large title collapses into a soft-edged bar '
        '${brightness.name}', (tester) async {
      await pump(
        tester,
        browsePage(
          bar: IosLargeTitleBar(
            title: 'Drive',
            titleInset: 20,
            backgroundColor: Colors.white,
            trailing: glass('More'),
          ),
        ),
        brightness: brightness,
      );
      await preview(tester, 'large-title-${brightness.name}-top');
      // At rest: large title shown, inline title hidden, bar transparent.
      expect(barTitleOpacity(tester, 'Drive'), 0);
      expect(barBackgroundOpacity(tester), 0);
      final large = tester.getRect(find.text('Drive').first);
      expect(large.left, 20);
      expect(large.top, greaterThanOrEqualTo(62 + IosPageMetrics.barHeight));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await preview(tester, 'large-title-${brightness.name}-collapsed');
      expect(barTitleOpacity(tester, 'Drive'), 1);
      expect(barBackgroundOpacity(tester), 1);
      // The glass control sits wholly inside the 44-point bar at the margin,
      // and no hard bar edge is drawn across it.
      final more = tester.getRect(find.byKey(const ValueKey('More')));
      expect(more.top, 62);
      expect(more.bottom, 62 + IosPageMetrics.barHeight);
      expect(more.right, 402 - IosPageMetrics.margin);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(barTitleOpacity(tester, 'Drive'), 0);
      expect(barBackgroundOpacity(tester), 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a pushed browsing page reveals its title after the hero', (
    tester,
  ) async {
    await pump(
      tester,
      browsePage(
        hero: true,
        bar: IosInlineTitleBar(
          title: 'Archive',
          hasHero: true,
          backgroundColor: Colors.white,
          leading: glass('Back'),
          trailing: glass('More'),
        ),
      ),
    );
    await preview(tester, 'browse-hero-top');
    expect(barTitleOpacity(tester, 'Archive'), 0);
    expect(barBackgroundOpacity(tester), 0);
    expect(tester.getRect(find.byKey(const ValueKey('Back'))).left, 16);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(barTitleOpacity(tester, 'Archive'), 1);
    expect(barBackgroundOpacity(tester), 1);
    // Taps on the bar do not reach the rows scrolled beneath it.
    await tester.tapAt(const Offset(200, 62 + 22));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large title fits 320 points at 200% text', (tester) async {
    await pump(
      tester,
      browsePage(
        bar: IosLargeTitleBar(
          title: 'Starred',
          trailing: glass('More'),
          leading: glass('Back'),
        ),
      ),
      width: 320,
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(barTitleOpacity(tester, 'Starred'), 1);
    expect(tester.takeException(), isNull);
  });
}
