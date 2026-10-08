import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/widgets/ios_menu/ios_menu_models.dart';
import 'package:flutter_m_fsdk/widgets/native_item_context_menu.dart';

class _Source extends StatefulWidget {
  const _Source();
  @override
  State<_Source> createState() => _SourceState();
}

class _SourceState extends State<_Source> {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 72, child: Text('A file row with cached content'));
}

void main() {
  testWidgets('native availability preserves the painted source row', (
    tester,
  ) async {
    final supported = Completer<bool>();
    const appearance = MethodChannel('teledrive/appearance');
    const views = MethodChannel('flutter/platform_views');
    String? nativeChannel;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appearance,
      (_) => supported.future,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        nativeChannel = '${args['viewType']}/${args['id']}';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(nativeChannel!),
          (_) async => null,
        );
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appearance,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        views,
        null,
      );
      if (nativeChannel != null) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(nativeChannel!),
          null,
        );
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: NativeItemContextMenu(
            identity: 'file:one',
            title: 'File',
            onOpen: () {},
            sectionsBuilder: () => [
              IosMenuSection([IosMenuItem(label: 'Open', onTap: () {})]),
            ],
            child: const _Source(),
          ),
        ),
      ),
    );
    final source = tester.state(find.byType(_Source));
    final bounds = tester.getRect(find.byType(_Source));
    supported.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsOneWidget);
    expect(tester.state(find.byType(_Source)), same(source));
    expect(tester.getRect(find.byType(_Source)), bounds);

    Future<void> visibility(String identity, bool visible) async {
      const codec = StandardMethodCodec();
      final response = Completer<void>();
      tester.binding.channelBuffers.push(
        nativeChannel!,
        codec.encodeMethodCall(
          MethodCall('visibility', {'identity': identity, 'visible': visible}),
        ),
        (_) => response.complete(),
      );
      await response.future;
      await tester.pump();
    }

    double opacity() => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byType(_Source),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    await visibility('file:one', true);
    expect(opacity(), 0);
    await visibility('file:one', false);
    expect(opacity(), 1);
    expect(tester.state(find.byType(_Source)), same(source));
    await visibility('stale:file', true);
    expect(opacity(), 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
