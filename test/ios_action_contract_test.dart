import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_action_sheet.dart';
import 'package:flutter_m_fsdk/widgets/sheet/adaptive_sheet.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/ios_menu_overlay.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/ios_menu_models.dart';

void main() {
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
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('Newest first'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
