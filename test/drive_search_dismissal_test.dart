import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_m_fsdk/features/search/search_controller.dart';
import 'package:flutter_m_fsdk/widgets/teledrive_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('search dismisses on touch outside and submit on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(
              body: Column(
                children: [
                  DriveSearchField(scope: SearchScope.drive),
                  Expanded(child: SizedBox.expand(key: ValueKey('outside'))),
                ],
              ),
            ),
          ),
        ),
      );
      final editable = find.byType(EditableText);
      await tester.enterText(editable, 'Travel');
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byKey(const ValueKey('outside')));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.widget<EditableText>(editable).controller.text, 'Travel');
      await tester.tap(editable);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.widget<EditableText>(editable).controller.text, 'Travel');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'iOS Search submits immediately, clear edits, and separate X cancels',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: const Scaffold(
              body: DriveSearchField(scope: SearchScope.drive),
            ),
          ),
        ),
      );
      final editable = find.byType(EditableText);
      await tester.enterText(editable, 'Travel');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        container.read(searchQueryProvider(SearchScope.drive)).query,
        'travel',
      );
      expect(find.text('Done'), findsNothing);
      await tester.tap(editable);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pumpAndSettle();
      expect(
        container.read(searchQueryProvider(SearchScope.drive)).query,
        isEmpty,
      );
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byTooltip('Cancel search'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
