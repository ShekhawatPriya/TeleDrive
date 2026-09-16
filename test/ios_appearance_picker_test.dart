import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/profile/widgets/ios_appearance_picker.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'appearance choices stay readable and selectable at text $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var mode = ThemeMode.system;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      IosAppearancePicker(
                        mode: mode,
                        onChanged: (next) => setState(() => mode = next),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        for (final entry in [
          ('Light', ThemeMode.light),
          ('Dark', ThemeMode.dark),
          ('System', ThemeMode.system),
        ]) {
          await tester.tap(find.text(entry.$1));
          await tester.pumpAndSettle();
          expect(mode, entry.$2);
          expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
          final selectedRow = find.ancestor(
            of: find.text(entry.$1),
            matching: find.byType(CupertinoListTile),
          );
          expect(
            find.descendant(
              of: selectedRow,
              matching: find.byIcon(CupertinoIcons.check_mark),
            ),
            findsOneWidget,
          );
          expect(tester.getSize(selectedRow).height, greaterThanOrEqualTo(44));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
