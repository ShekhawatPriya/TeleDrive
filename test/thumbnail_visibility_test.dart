import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_m_fsdk/core/media/thumbnail_scheduler.dart';
import 'package:flutter_m_fsdk/widgets/thumbnail_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'visible and nearby follow scrolling and inactive tabs stop work',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final priorities = <int, ThumbnailPriority?>{};
      Widget page(bool active) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: TickerMode(
              enabled: active,
              child: SizedBox(
                width: 300,
                height: 300,
                child: ListView.builder(
                  controller: scroll,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                  itemExtent: 100,
                  itemCount: 100,
                  itemBuilder: (_, i) => ThumbnailVisibility(
                    onChanged: (priority) => priorities[i] = priority,
                    child: Text('$i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(priorities[0], ThumbnailPriority.visible);
      expect(priorities[2], ThumbnailPriority.visible);
      expect(priorities[3], ThumbnailPriority.nearby);
      expect(priorities[6], isNull);
      scroll.jumpTo(400);
      await tester.pump();
      expect(priorities[0], isNull);
      expect(priorities[4], ThumbnailPriority.visible);
      expect(priorities[6], ThumbnailPriority.visible);
      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(priorities[4], isNull);
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(priorities[4], ThumbnailPriority.visible);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(priorities[4], isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(priorities[4], ThumbnailPriority.visible);
    },
  );

  testWidgets('nested viewport clips items and scroll listeners are removed', (
    tester,
  ) async {
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    ThumbnailPriority? priority;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 100,
            width: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              controller: horizontal,
              children: [
                const SizedBox(width: 500),
                SizedBox(
                  width: 100,
                  child: ThumbnailVisibility(
                    onChanged: (value) => priority = value,
                    child: const Text('target'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(priority, isNull);
    horizontal.jumpTo(400);
    await tester.pump();
    expect(priority, ThumbnailPriority.visible);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
