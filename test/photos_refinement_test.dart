import 'package:flutter_m_fsdk/features/photos/photos_grid/photos_grid_view.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_m_fsdk/core/media/photo_media_loader.dart';
import 'package:flutter_m_fsdk/core/media/photo_playback.dart';
import 'package:flutter_m_fsdk/features/photos/photos_filter.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/justified_photo_layout.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photo_grid_density.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photo_pan_selector.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_session.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_stage.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_video.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

DriveFile photo(
  String id, {
  String? name,
  FileKind kind = FileKind.image,
  int? w = 1200,
  int? h = 800,
}) => DriveFile(
  id: id,
  name: name ?? '$id.jpg',
  kind: kind,
  size: 0,
  modifiedAt: '2026-10-01',
  createdAt: '2026-10-01',
  parentId: null,
  starred: false,
  widthPx: w,
  heightPx: h,
);

class PendingMedia implements PhotoMediaLoader {
  final requests = <(CancelToken, Completer<String>)>[];
  @override
  String revision(DriveFile file) => '${file.id}:${file.modifiedAt}';
  @override
  Future<String> video(
    DriveFile file,
    CancelToken token, {
    ProgressCallback? progress,
  }) {
    final pending = Completer<String>();
    requests.add((token, pending));
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> viewer(
  WidgetTester tester, {
  required GlobalKey<PhotoViewerStageState> key,
  bool zoomed = false,
  bool reduced = false,
  VoidCallback? dismissed,
  Future<Rect?> Function()? destination,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduced,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.blue)),
            PhotoViewerStage(
              key: key,
              sourceRect: const Rect.fromLTWH(20, 160, 120, 100),
              mediaAspectRatio: 1.5,
              mediaZoomed: zoomed,
              prepareDismiss: destination,
              onDismissed: dismissed ?? () {},
              onDetailsChanged: () {},
              header: const SizedBox(height: 44),
              footer: const SizedBox(height: 44),
              detailsBuilder: (scroll) => ListView(
                controller: scroll,
                children: List.generate(30, (i) => Text('Metadata $i')),
              ),
              media: const Center(
                child: SizedBox(
                  width: 390,
                  height: 260,
                  child: ColoredBox(
                    key: ValueKey('test-photo'),
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'viewer scope retains query and media type, reconciles by identity and neighbor',
    () {
      final session = PhotoViewerSession(
        filter: PhotosFilter.photos,
        query: ' trip ',
        currentId: 'b',
        generation: 7,
      );
      final a = photo('a', name: 'Trip first.jpg'),
          b = photo('b', name: 'Trip second.jpg');
      expect(
        session
            .reconcile([
              a,
              photo('v', name: 'Trip.mp4', kind: FileKind.video),
              b,
              photo('x'),
            ])
            .map((f) => f.id),
        ['a', 'b'],
      );
      expect(session.index, 1);
      session.reconcile([b, a]);
      expect(session.currentId, 'b');
      expect(session.index, 0);
      session.reconcile([a]);
      expect(session.currentId, 'a');
      expect(session.reconcile([]), isEmpty);
    },
  );
  test('mosaic has bounded feature blocks and square mode is uniform', () {
    final files = List.generate(
      120,
      (i) =>
          photo('$i', w: i % 3 == 0 ? 500 : 1800, h: i % 3 == 0 ? 1800 : 900),
    );
    for (final width in [280.0, 350.0, 800.0]) {
      for (final columns in [2, 3, 4, 5]) {
        final mosaic = layoutPhotos(
          files,
          width: width,
          columns: columns,
          gap: 4,
        );
        for (var i = 0; i < mosaic.rects.length; i++) {
          final r = mosaic.rects[i];
          expect(r.shortestSide, greaterThanOrEqualTo(44 - .0001));
          expect(r.right, lessThanOrEqualTo(width + .01));
          for (var j = i + 1; j < mosaic.rects.length; j++) {
            expect(r.overlaps(mosaic.rects[j]), isFalse);
          }
        }
        final square = layoutPhotos(
          files,
          width: width,
          columns: columns,
          gap: 4,
          square: true,
        );
        expect(
          square.rects.every((r) => (r.width - r.height).abs() < .001),
          isTrue,
        );
      }
    }
  });
  test('appending a page retains completed mosaic blocks', () {
    final files = List.generate(100, (i) => photo('$i'));
    final before = layoutPhotos(
      files.take(60).toList(),
      width: 350,
      columns: 3,
      gap: 4,
    );
    final after = layoutPhotos(files, width: 350, columns: 3, gap: 4);
    expect(before.rects.take(54).toList(), after.rects.take(54).toList());
  });
  test(
    'mosaic choice survives preference reload without changing density',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PhotoGridDensity();
      await Future<void>.delayed(Duration.zero);
      await prefs.set(2);
      await prefs.setStyle(PhotoGridStyle.square);
      prefs.dispose();
      final restored = PhotoGridDensity();
      await Future<void>.delayed(Duration.zero);
      expect(restored.columns, 2);
      expect(restored.style, PhotoGridStyle.square);
      restored.dispose();
    },
  );
  testWidgets('return to an offscreen photo reveals its actual tile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final grid = GlobalKey<PhotosGridViewState>();
    final density = PhotoGridDensity();
    addTearDown(density.dispose);
    final files = List.generate(1000, (i) => photo('$i'));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: PhotosGridView(
              key: grid,
              files: files,
              density: density,
              onLoadMore: () {},
              loadingMore: false,
              selectMode: false,
              selectedIds: const {},
              onTileTap: (_) {},
              onTileLongPress: (_, __) {},
              onTilePanSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(grid.currentState!.sourceRect('800'), isNull);
    final pending = grid.currentState!.revealFile('800');
    await tester.pumpAndSettle();
    final rect = await pending;
    expect(rect, isNotNull);
    expect(
      rect!.center.dy,
      inInclusiveRange(0, tester.getSize(find.byType(PhotosGridView)).height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dismissal follows both axes and reveals library; a short drag restores',
    (tester) async {
      var closed = 0;
      final key = GlobalKey<PhotoViewerStageState>();
      await viewer(tester, key: key, dismissed: () => closed++);
      final before = tester.getRect(find.byKey(const ValueKey('test-photo')));
      final touch = await tester.startGesture(const Offset(190, 380));
      await touch.moveBy(const Offset(0, 24));
      await tester.pump();
      await touch.moveBy(const Offset(40, 90));
      await tester.pump();
      final moved = tester.getRect(find.byKey(const ValueKey('test-photo')));
      expect(moved.center.dx, greaterThan(before.center.dx + 20));
      expect(moved.center.dy, greaterThan(before.center.dy + 50));
      expect(moved.width, lessThan(before.width));
      final backdrop = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('viewer-backdrop')),
      );
      expect(backdrop.color.a, lessThan(1));
      await tester.pump(const Duration(milliseconds: 300));
      await touch.up();
      await tester.pumpAndSettle();
      expect(closed, 0);
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('viewer-backdrop')))
            .color
            .a,
        1,
      );
      expect(
        (tester.getRect(find.byKey(const ValueKey('test-photo'))).center -
                before.center)
            .distance,
        lessThan(.01),
      );
    },
  );
  testWidgets(
    'long dismissal prepares current destination and completes once',
    (tester) async {
      var closed = 0, prepared = 0;
      final key = GlobalKey<PhotoViewerStageState>();
      await viewer(
        tester,
        key: key,
        dismissed: () => closed++,
        destination: () async {
          prepared++;
          return const Rect.fromLTWH(230, 500, 130, 110);
        },
      );
      await tester.dragFrom(const Offset(190, 360), const Offset(25, 280));
      await tester.pumpAndSettle();
      expect(prepared, 1);
      expect(closed, 1);
    },
  );
  testWidgets('zoom and inspector retain vertical gesture ownership', (
    tester,
  ) async {
    var closed = 0;
    final key = GlobalKey<PhotoViewerStageState>();
    await viewer(tester, key: key, zoomed: true, dismissed: () => closed++);
    await tester.dragFrom(const Offset(190, 360), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(closed, 0);
    await viewer(tester, key: key, dismissed: () => closed++);
    key.currentState!.toggle();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('viewer-details-handle')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(closed, 0);
    expect(key.currentState!.isOpen, isFalse);
  });
  testWidgets(
    'upward reversal cancels even after crossing distance threshold',
    (tester) async {
      var closed = 0;
      final key = GlobalKey<PhotoViewerStageState>();
      await viewer(tester, key: key, dismissed: () => closed++);
      final touch = await tester.startGesture(const Offset(190, 300));
      await touch.moveBy(const Offset(0, 260));
      await tester.pump(const Duration(milliseconds: 250));
      for (var i = 0; i < 4; i++) {
        await touch.moveBy(const Offset(0, -12));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await touch.up();
      await tester.pumpAndSettle();
      expect(closed, 0);
    },
  );
  testWidgets(
    'inactive video cancels preparation and ignores late completion',
    (tester) async {
      final loader = PendingMedia();
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [photoMediaLoaderProvider.overrideWithValue(loader)],
          child: MaterialApp(
            home: ValueListenableBuilder(
              valueListenable: active,
              builder: (_, value, __) => PhotoViewerVideo(
                file: photo('v', kind: FileKind.video),
                isActive: value,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(loader.requests.length, 1);
      active.value = false;
      await tester.pump();
      expect(loader.requests.first.$1.isCancelled, isTrue);
      loader.requests.first.$2.complete('/not-an-actual-video.mp4');
      await tester.pump();
      expect(find.text('Could not play this video.'), findsNothing);
      active.value = true;
      await tester.pump();
      expect(loader.requests.length, 2);
      await tester.pumpWidget(const SizedBox());
      loader.requests.last.$2.complete('/ignored.mp4');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('AVKit host survives readiness and buffering changes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('teledrive/appearance'),
      (call) async => call.method == 'supportsPhotoVideo',
    );
    final created = <int>[];
    String? session;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter/platform_views'),
      (call) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final id = args['id'] as int;
          created.add(id);
          final params =
              const StandardMessageCodec().decodeMessage(
                    ByteData.sublistView(args['params'] as Uint8List),
                  )
                  as Map;
          session = params['session'] as String;
          messenger.setMockMethodCallHandler(
            MethodChannel('teledrive/photo-video/$id'),
            (_) async => null,
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
          MethodChannel('teledrive/photo-video/$id'),
          null,
        );
      }
    });
    final loader = PendingMedia();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoMediaLoaderProvider.overrideWithValue(loader)],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: PhotoViewerVideo(
            file: photo('v', kind: FileKind.video),
            isActive: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    loader.requests.single.$2.complete('/fixture.mp4');
    await tester.pump();
    await tester.pump();
    expect(created, hasLength(1));
    for (final ready in [true, false, true]) {
      final done = Completer<void>();
      messenger.handlePlatformMessage(
        'teledrive/photo-video/${created.first}',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('state', {
            'session': session,
            'ready': ready,
            'buffering': !ready,
          }),
        ),
        (_) => done.complete(),
      );
      await done.future;
      await tester.pump();
      await tester.pump();
      expect(created, hasLength(1));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native bridge discards obsolete session events and unregisters on dispose',
    (tester) async {
      final events = <PhotoPlaybackEvent>[];
      final bridge = NativePhotoPlayback(
        400,
        session: 'new',
        onEvent: events.add,
      );
      Future<void> send(String session) async {
        final done = Completer<void>();
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'teledrive/photo-video/400',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('state', {'session': session, 'ready': true}),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }

      await send('old');
      expect(events, isEmpty);
      await send('new');
      expect(events.single.ready, isTrue);
      bridge.dispose();
      await tester.pump();
    },
  );
  testWidgets('range selection can reverse and edge-autoscroll', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final keys = {for (var i = 0; i < 100; i++) '$i': GlobalKey()};
    final ranges = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 500,
          child: PhotoPanSelector(
            enabled: true,
            tileKeys: keys,
            scrollController: scroll,
            orderedIds: keys.keys.toList(),
            onTilePan: (_) {},
            onRange: (a, b) => ranges.add((a, b)),
            child: GridView.builder(
              controller: scroll,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
              itemCount: 100,
              itemBuilder: (_, i) =>
                  SizedBox(key: keys['$i'], child: Text('$i')),
            ),
          ),
        ),
      ),
    );
    final first = tester.getCenter(find.text('0')),
        second = tester.getCenter(find.text('2'));
    final touch = await tester.startGesture(first);
    await touch.moveBy(const Offset(25, 0));
    await tester.pump();
    await touch.moveTo(second);
    await tester.pump();
    await touch.moveTo(first);
    await tester.pump();
    expect(ranges.last, ('0', '0'));
    final size = tester.getSize(find.byType(PhotoPanSelector));
    await touch.moveTo(Offset(first.dx, size.height - 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(scroll.offset, greaterThan(0));
    await touch.up();
    await tester.pumpAndSettle();
  });
}
