import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_header_widgets.dart';

void main() {
  testWidgets('DriveQuickActions renders trash action successfully', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DriveQuickActions(onTrashTap: () => tapped = true),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Trash'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.text('Trash'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
