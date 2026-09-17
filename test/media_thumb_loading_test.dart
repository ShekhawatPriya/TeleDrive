import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'platform_folder_ui_test.dart' show capture;
import 'package:flutter_m_fsdk/core/media/thumbnail_loader.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/media_thumb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DriveFile photo(int id) => DriveFile(
  id: '$id',
  name: '$id.jpg',
  kind: FileKind.image,
  size: 100,
  createdAt: '',
  modifiedAt: '',
  parentId: null,
  starred: false,
  thumbnailRefAvailable: true,
);

class _Loader implements ThumbnailLoader {
  final requests = <String>[];
  final tokens = <String, CancelToken>{};
  bool fail = false;
  final hits = <String, File>{};
  @override
  String keyFor(DriveFile file) => file.id;
  @override
  bool hasSources(DriveFile file) => true;
  @override
  bool canUseOriginal(DriveFile file) => false;
  @override
  Future<File?> cached(DriveFile file) async => hits[file.id];
  @override
  Future<File?> load(
    DriveFile file,
    CancelToken token, {
    bool original = false,
  }) async {
    requests.add(file.id);
    tokens[file.id] = token;
    if (fail) return null;
    await token.whenCancel;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'retry states fit 320px and 200% text $platform $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final loader = _Loader()..fail = true;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [thumbnailLoaderProvider.overrideWithValue(loader)],
              child: MaterialApp(
                theme: ThemeData(platform: platform, brightness: brightness),
                home: RepaintBoundary(
                  key: const ValueKey('preview'),
                  child: Scaffold(
                    body: MediaQuery(
                      data: const MediaQueryData(
                        size: Size(320, 480),
                        textScaler: TextScaler.linear(2),
                        highContrast: true,
                        disableAnimations: true,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: MediaThumb(file: photo(1)),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: MediaThumb(file: photo(2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.byTooltip('Retry preview for 1.jpg'), findsOneWidget);
          expect(find.byTooltip('Retry preview for 2.jpg'), findsNothing);
          expect(
            tester.getSize(find.byType(IconButton)).shortestSide,
            greaterThanOrEqualTo(44),
          );
          expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
          await capture(
            tester,
            'thumbnail-retry-${platform.name}-${brightness.name}',
          );
          final before = loader.requests.length;
          await tester.tap(find.byTooltip('Retry preview for 1.jpg'));
          await tester.pump();
          expect(loader.requests.length, before + 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'a cancelled request that is now visible re-enters without backoff',
    (tester) async {
      final loader = _Loader();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [thumbnailLoaderProvider.overrideWithValue(loader)],
          child: MaterialApp(
            home: SizedBox(
              width: 100,
              height: 100,
              child: MediaThumb(file: photo(1)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(loader.requests, hasLength(1));
      loader.tokens['1']!.cancel(
        'Prefetch preempted as the tile becomes visible',
      );
      await tester.pump();
      await tester.pump();
      expect(loader.requests, hasLength(2));
      expect(find.byTooltip('Retry preview for 1.jpg'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cached thumbnail bypasses saturated network admission', (
    tester,
  ) async {
    final loader = _Loader();
    final fixture = File('test/fixtures/design/alpine.jpg').absolute;
    loader.hits['4'] = fixture;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [thumbnailLoaderProvider.overrideWithValue(loader)],
        child: MaterialApp(
          home: Column(
            children: [
              for (var i = 0; i < 5; i++)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: MediaThumb(file: photo(i)),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(loader.requests, ['0', '1', '2', '3']);
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'scrolling admits the new viewport and tab exit cancels old loads',
    (tester) async {
      final loader = _Loader();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Widget page(bool active) => ProviderScope(
        overrides: [thumbnailLoaderProvider.overrideWithValue(loader)],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TickerMode(
                enabled: active,
                child: SizedBox(
                  height: 300,
                  width: 300,
                  child: ListView.builder(
                    controller: scroll,
                    scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                    itemCount: 50,
                    itemExtent: 100,
                    itemBuilder: (_, i) => MediaThumb(file: photo(i)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      await tester.pump();
      expect(loader.requests.take(3), ['0', '1', '2']);
      expect(loader.requests.length, lessThanOrEqualTo(4));
      scroll.jumpTo(1000);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(loader.tokens['0']!.isCancelled, isTrue);
      expect(loader.requests, containsAll(['10', '11', '12']));
      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(loader.tokens['10']!.isCancelled, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'visible failure retries with backoff then stops; revisit recovers',
    (tester) async {
      final loader = _Loader()..fail = true;
      Widget page(bool active) => ProviderScope(
        overrides: [thumbnailLoaderProvider.overrideWithValue(loader)],
        child: MaterialApp(
          home: TickerMode(
            enabled: active,
            child: SizedBox(
              width: 100,
              height: 100,
              child: MediaThumb(file: photo(1)),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      await tester.pump();
      expect(loader.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(loader.requests, hasLength(2));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(loader.requests, hasLength(3));
      await tester.pump(const Duration(minutes: 1));
      expect(loader.requests, hasLength(3));
      await tester.pumpWidget(page(false));
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(loader.requests, hasLength(4));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
