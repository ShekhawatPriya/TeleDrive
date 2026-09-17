import 'package:flutter/services.dart';
import 'dart:ui' show SemanticsAction;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_action_sheet.dart';
import 'package:flutter_m_fsdk/widgets/sheet/adaptive_sheet.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/ios_menu_overlay.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/ios_menu_models.dart';

void main() {
  for (final dismissal in ['drag', 'backdrop', 'escape', 'semantics']) {
    testWidgets('iOS action sheet cancels through $dismissal without a cross', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      String? result = 'pending';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAdaptiveSheet<String>(
                    context: context,
                    builder: (_) => const DriveActionSheet(
                      title: 'Weekend plans',
                      actions: [
                        SheetActionItem(
                          id: 'share',
                          label: 'Share',
                          icon: Icons.share,
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
      switch (dismissal) {
        case 'drag':
          await tester.fling(
            find.text('Weekend plans'),
            const Offset(0, 350),
            1000,
          );
        case 'backdrop':
          await tester.tapAt(const Offset(8, 80));
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'semantics':
          final node = tester.getSemantics(
            find.bySemanticsLabel('Dismiss sheet'),
          );
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.dismiss),
            isTrue,
          );
          node.owner!.performAction(node.id, SemanticsAction.dismiss);
      }
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Weekend plans'), findsNothing);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  for (final keyboard in [0.0, 260.0]) {
    testWidgets(
      'iOS sheet corners clear the home indicator and keyboard $keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
        tester.view.padding = FakeViewPadding(
          top: 62,
          bottom: keyboard == 0 ? 34 : 0,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAdaptiveSheet<void>(
                    context: context,
                    builder: (_) => Column(
                      children: [
                        for (var i = 0; i < 30; i++)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('Action $i'),
                          ),
                      ],
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const ValueKey('ios-action-sheet-surface')),
        );
        expect(rect.left, 12);
        expect(rect.right, 390);
        expect(rect.top, greaterThanOrEqualTo(62));
        expect(
          rect.bottom,
          lessThanOrEqualTo(874 - keyboard - (keyboard == 0 ? 34 : 12)),
        );
        expect(find.byType(ClipRSuperellipse), findsOneWidget);
        await tester.ensureVisible(find.text('Action 29'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('iOS item sheet preserves every action at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? result;
    const actions = [
      SheetActionItem(id: 'share', label: 'Share', icon: Icons.share),
      SheetActionItem(id: 'star', label: 'Star', icon: Icons.star),
      SheetActionItem(id: 'rename', label: 'Rename', icon: Icons.edit),
      SheetActionItem(id: 'move', label: 'Move', icon: Icons.folder),
      SheetActionItem(
        id: 'delete',
        label: 'Move to Trash',
        icon: Icons.delete,
        destructive: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await showAdaptiveSheet<String>(
                  context: context,
                  builder: (_) => const DriveActionSheet(
                    title: 'A long folder title for travelling together',
                    actions: actions,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    for (final action in actions) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final control = find.widgetWithText(CupertinoButton, action.label);
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(result, action.id);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('iOS popup keeps selection and dismisses after action', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => Navigator.of(context).push(
                IosMenuOverlayRoute(
                  anchor: const Rect.fromLTWH(250, 70, 44, 44),
                  sections: [
                    IosMenuSection([
                      IosMenuItem(
                        label: 'Newest first',
                        checked: true,
                        onTap: () => selected = true,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('Newest first'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
