import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/upload/upload_source_picker.dart';

void main() {
  testWidgets('source chooser anchors to the visible initiating control', (
    tester,
  ) async {
    MethodCall? request;
    const channel = MethodChannel('teledrive/appearance');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      request = call;
      return 'photos';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    String? selected;
    await tester.pumpWidget(
      CupertinoApp(
        home: Stack(
          children: [
            Positioned(
              right: 24,
              bottom: 120,
              width: 60,
              height: 60,
              child: Builder(
                builder: (context) => CupertinoButton(
                  onPressed: () async {
                    selected = await chooseUploadSource(context);
                  },
                  child: const Text('+'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final rect = tester.getRect(find.byType(CupertinoButton));
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(request?.method, 'chooseUploadSource');
    expect(request?.arguments, {
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
    });
    expect(selected, 'photos');
  });
}
