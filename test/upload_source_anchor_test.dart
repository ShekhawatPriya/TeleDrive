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
      'dark': false,
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
    });
    expect(selected, 'photos');
  });

  testWidgets('source chooser uses the app appearance over system appearance', (
    tester,
  ) async {
    const channel = MethodChannel('teledrive/appearance');
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final requests = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      requests.add(Map<Object?, Object?>.from(call.arguments as Map));
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue =
          brightness == Brightness.dark ? Brightness.light : Brightness.dark;
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => chooseUploadSource(context),
              child: const Text('Upload'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Upload'));
      await tester.pump();
      expect(requests.last['dark'], brightness == Brightness.dark);
    }
  });
}
