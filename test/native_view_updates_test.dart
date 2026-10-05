import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/widgets/native_glass_button.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/native_photo_controls.dart';

void main() {
  testWidgets(
    'unchanged glass controls skip IPC while menus request current state',
    (tester) async {
      const codec = StandardMethodCodec();
      final updates = <MethodCall>[];
      String? nativeChannel;
      const appearance = MethodChannel('teledrive/appearance');
      const views = MethodChannel('flutter/platform_views');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appearance,
        (_) async => true,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          nativeChannel = '${args['viewType']}/${args['id']}';
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(nativeChannel!),
            (call) async {
              updates.add(call);
              return null;
            },
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
        if (nativeChannel != null)
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(nativeChannel!),
            null,
          );
      });
      var checked = false;
      Widget app() => MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Center(
          child: NativeGlassButton(
            label: 'More',
            symbol: 'ellipsis',
            icon: CupertinoIcons.ellipsis,
            onPressed: () {},
            menuBuilder: () => [
              {
                'items': [
                  {'label': 'List', 'checked': checked},
                ],
              },
            ],
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      final initialCount = updates.length;
      expect(initialCount, greaterThan(0));
      checked = true;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(updates.length, initialCount);
      final response = Completer<Object?>();
      tester.binding.channelBuffers.push(
        nativeChannel!,
        codec.encodeMethodCall(const MethodCall('menuRequest')),
        (data) {
          response.complete(codec.decodeEnvelope(data!));
        },
      );
      final menu = (await response.future) as List;
      expect(((menu.first as Map)['items'] as List).first['checked'], isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'photo toolbar sends state changes but ignores callback-only rebuilds',
    (tester) async {
      final updates = <MethodCall>[];
      String? nativeChannel;
      const appearance = MethodChannel('teledrive/appearance');
      const views = MethodChannel('flutter/platform_views');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appearance,
        (_) async => true,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          nativeChannel = '${args['viewType']}/${args['id']}';
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(nativeChannel!),
            (call) async {
              updates.add(call);
              return null;
            },
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
        if (nativeChannel != null)
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel(nativeChannel!),
            null,
          );
      });
      Widget app(bool starred) => MaterialApp(
        home: NativePhotoControls(
          starred: starred,
          infoSelected: false,
          onStar: () {},
          onInfo: () {},
          onShare: () {},
          onDelete: () {},
          fallback: const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      final initialCount = updates.length;
      expect(initialCount, greaterThan(0));
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(updates.length, initialCount);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(updates.length, initialCount + 1);
      final actions = (updates.last.arguments as Map)['actions'] as List;
      expect((actions[1] as Map)['symbol'], 'star.fill');
      expect((actions[1] as Map)['label'], 'Remove star');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
