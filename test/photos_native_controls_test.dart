import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/features/photos/components/photos_library_controls.dart';
import 'package:flutter_m_fsdk/features/photos/photos_filter.dart';
import 'package:flutter_m_fsdk/features/search/search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'one UIKit host survives category, search, cancel and appearance updates',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger = tester.binding.defaultBinaryMessenger;
      final created = <int>[];
      final updates = <Map>[];
      final calls = <String>[];
      final filter = ValueNotifier(PhotosFilter.all);
      final large = ValueNotifier(false);
      final container = ProviderContainer();
      addTearDown(filter.dispose);
      addTearDown(large.dispose);
      addTearDown(container.dispose);
      messenger.setMockMethodCallHandler(
        const MethodChannel('teledrive/appearance'),
        (call) async => call.method == 'supportsPhotosControls',
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform_views'),
        (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            expect(args['viewType'], 'teledrive/photos-controls');
            final id = args['id'] as int;
            created.add(id);
            updates.add(
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(args['params'] as Uint8List),
                  )
                  as Map,
            );
            messenger.setMockMethodCallHandler(
              MethodChannel('teledrive/photos-controls/$id'),
              (call) async {
                calls.add(call.method);
                if (call.method == 'update') updates.add(call.arguments as Map);
                return null;
              },
            );
          }
          return null;
        },
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('teledrive/appearance'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter/platform_views'),
          null,
        );
        for (final id in created) {
          messenger.setMockMethodCallHandler(
            MethodChannel('teledrive/photos-controls/$id'),
            null,
          );
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: large,
                builder: (_, value, _) => MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(value ? 2 : 1),
                    disableAnimations: value,
                    highContrast: value,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: filter,
                    builder: (_, value, _) => PhotosLibraryControls(
                      filter: value,
                      onFilterChanged: (value) => filter.value = value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(find.byType(EditableText), findsNothing);
      Future<void> event(String method, [Object? value]) async {
        final done = Completer<void>();
        messenger.handlePlatformMessage(
          'teledrive/photos-controls/${created.single}',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, value),
          ),
          (_) => done.complete(),
        );
        await done.future;
        await tester.pump();
      }

      await event('selected', 2);
      expect(filter.value, PhotosFilter.videos);
      await event('searching', true);
      await event('changed', 'Weekend');
      await event('submitted');
      expect(
        container.read(searchQueryProvider(SearchScope.photos)).query,
        'weekend',
      );
      expect(updates.last['selected'], 2);
      expect(updates.last['searching'], true);
      await event('cancelled');
      expect(
        container.read(searchQueryProvider(SearchScope.photos)).query,
        isEmpty,
      );
      expect(filter.value, PhotosFilter.videos);
      large.value = true;
      await tester.pumpAndSettle();
      expect(updates.last['textScale'], 2);
      expect(updates.last['reduceMotion'], true);
      expect(updates.last['highContrast'], true);
      expect(
        created,
        hasLength(1),
        reason: 'Material morphs must stay inside a retained native hierarchy',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, contains('dispose'));
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
