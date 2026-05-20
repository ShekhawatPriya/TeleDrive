import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_header_widgets.dart';

void main() {
  testWidgets('DriveStoragePill renders successfully inside SliverToBoxAdapter', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DriveStoragePill(used: 120 * 1024 * 1024), // 120 MB
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Verify that the storage card text renders correctly
    expect(find.text('120 MB used'), findsOneWidget);
    // Verify that the cloud icon renders
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    // Verify that the progress indicator renders
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
