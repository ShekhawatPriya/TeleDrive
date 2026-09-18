import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/profile/cache_controller.dart';
import 'package:flutter_m_fsdk/features/photos/photos_filter.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_screen.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_stage.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_filmstrip.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_pager.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_details_sheet.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

final path = File('test/fixtures/design/alpine.jpg').absolute.path;
final files = List.generate(
  12,
  (i) => DriveFile(
    id: 'p$i',
    name: 'Alpine $i.jpg',
    kind: FileKind.image,
    size: 407000,
    modifiedAt: '2026-09-17T14:31:00Z',
    createdAt: '2026-09-17T14:31:00Z',
    parentId: null,
    starred: false,
    previewUrl: path,
    thumbnailUrl: path,
    widthPx: 1242,
    heightPx: 2208,
  ),
);

class Drive extends ChangeNotifier implements DriveController {
  List<DriveFile> items = [...files];
  @override
  List<DriveFile> photoFiles(String filter) => items;
  @override
  Future<void> markAccessed(String id) async {}
  @override
  Future<void> toggleStar(String id, {bool folder = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Cache extends ChangeNotifier implements CacheController {
  @override
  Future<void> refreshCacheStats() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

late ui.Image fixture;
late ui.Image portraitFixture;
late ui.Image panoramaFixture;
late ui.Image tallFixture;
late ui.Image squareFixture;
Future<void> preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        )
        .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/modernization/viewer-$name.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> pump(
  WidgetTester tester,
  TargetPlatform platform,
  Brightness brightness, {
  double width = 390,
  double scale = 1,
  bool reduced = false,
  Drive? drive,
  bool portrait = false,
  ui.Image? sourceImage,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  for (final size in [0, 96, 192, 288, 320, 640, 960]) {
    final ImageProvider provider = size == 0
        ? FileImage(File(path))
        : ResizeImage(FileImage(File(path)), width: size);
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.evict(key);
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        Future.value(
          ImageInfo(
            image: (sourceImage ?? (portrait ? portraitFixture : fixture))
                .clone(),
          ),
        ),
      ),
    );
  }
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(AppBrand.scheme(brightness));
  debugDefaultTargetPlatformOverride = null;
  final input = sourceImage ?? (portrait ? portraitFixture : fixture);
  final fixtureDrive = drive ?? Drive();
  fixtureDrive.items = [
    for (final file in fixtureDrive.items)
      file.copyWith(widthPx: input.width, heightPx: input.height),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driveControllerProvider.overrideWith((_) => fixtureDrive),
        cacheControllerProvider.overrideWith((_) => Cache()),
      ],
      child: MaterialApp(
        theme: theme.copyWith(
          platform: platform,
          textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            padding: const EdgeInsets.only(top: 54, bottom: 24),
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
            highContrast: reduced,
          ),
          child: const RepaintBoundary(
            key: ValueKey('preview'),
            child: PhotoViewerScreen(startId: 'p4', filter: PhotosFilter.all),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    fixture = (await codec.getNextFrame()).image;
    codec.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      fixture,
      Rect.fromLTWH(
        fixture.width * .35,
        0,
        fixture.height * .6,
        fixture.height.toDouble(),
      ),
      const Rect.fromLTWH(0, 0, 240, 400),
      Paint(),
    );
    final picture = recorder.endRecording();
    portraitFixture = await picture.toImage(240, 400);
    picture.dispose();
    Future<ui.Image> cropped(int width, int height) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final source = Size(fixture.width.toDouble(), fixture.height.toDouble());
      final destination = Size(width.toDouble(), height.toDouble());
      final fit = applyBoxFit(BoxFit.cover, source, destination);
      canvas.drawImageRect(
        fixture,
        Alignment.center.inscribe(fit.source, Offset.zero & source),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint(),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      return image;
    }

    panoramaFixture = await cropped(1200, 100);
    tallFixture = await cropped(100, 1200);
    squareFixture = await cropped(400, 400);
    for (final family in ['Inter', 'Roboto', '.SF Pro Text']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  tearDownAll(() {
    fixture.dispose();
    portraitFixture.dispose();
    panoramaFixture.dispose();
    tallFixture.dispose();
    squareFixture.dispose();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      testWidgets('viewer gestures and previews $platform $brightness', (
        tester,
      ) async {
        await pump(tester, platform, brightness);
        expect(tester.takeException(), isNull);
        await preview(tester, '${platform.name}-${brightness.name}-closed');
        await tester.drag(find.byType(PhotoViewerPager), const Offset(-280, 0));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PhotoViewerFilmstrip>(find.byType(PhotoViewerFilmstrip))
              .index,
          5,
        );
        await tester.dragFrom(const Offset(190, 450), const Offset(0, -280));
        await tester.pumpAndSettle();
        final stage = tester.state<PhotoViewerStageState>(
          find.byType(PhotoViewerStage),
        );
        expect(stage.isOpen, isTrue);
        expect(find.byType(PhotoViewerFilmstrip), findsNothing);
        await preview(tester, '${platform.name}-${brightness.name}-info');
        await tester.dragFrom(const Offset(190, 590), const Offset(0, -460));
        await tester.pumpAndSettle();
        await preview(tester, '${platform.name}-${brightness.name}-expanded');
        expect(find.byTooltip('Share'), findsOneWidget);
        expect(find.byTooltip('Delete'), findsOneWidget);
        await tester.tap(find.byTooltip('Info'));
        await tester.pumpAndSettle();
        expect(stage.isOpen, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('viewer accessible $platform', (tester) async {
      await pump(
        tester,
        platform,
        Brightness.dark,
        width: 320,
        scale: 2,
        reduced: true,
      );
      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await preview(tester, '${platform.name}-accessible');
    });
  }
  testWidgets(
    'landscape information meets the visible photo without letterboxing',
    (tester) async {
      await pump(tester, TargetPlatform.iOS, Brightness.dark);
      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();
      final panelTop = tester
          .getTopLeft(find.byKey(const ValueKey('viewer-details-surface')))
          .dy;
      expect(panelTop, closeTo(844 * .45, 1));
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')),
            )
            .toImage();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (((panelTop - 2).floor() * image.width) + 195) * 4;
        expect(
          pixels.getUint8(offset) +
              pixels.getUint8(offset + 1) +
              pixels.getUint8(offset + 2),
          greaterThan(40),
        );
        image.dispose();
      });
    },
  );
  testWidgets(
    'portrait detail expansion and interrupted motion remain continuous',
    (tester) async {
      await pump(tester, TargetPlatform.iOS, Brightness.dark, portrait: true);
      await preview(tester, 'iOS-portrait-closed');
      await tester.tap(find.byTooltip('Info'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<PhotoViewerStageState>(find.byType(PhotoViewerStage))
            .isOpen,
        isFalse,
      );
      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();
      await preview(tester, 'iOS-portrait-info');
      await tester.dragFrom(const Offset(190, 580), const Offset(0, -460));
      await tester.pumpAndSettle();
      await preview(tester, 'iOS-portrait-expanded');
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('all aspect ratios stay bounded at the Info opening $platform', (
      tester,
    ) async {
      for (final source in [
        fixture,
        portraitFixture,
        panoramaFixture,
        tallFixture,
        squareFixture,
      ]) {
        await pump(tester, platform, Brightness.dark, sourceImage: source);
        await tester.tap(find.byTooltip('Info'));
        await tester.pumpAndSettle();
        final panelTop = tester
            .getTopLeft(find.byKey(const ValueKey('viewer-details-surface')))
            .dy;
        expect(panelTop, closeTo(844 * .45, 1));
        final media = tester.renderObject<RenderBox>(
          find.byType(PhotoViewerPager),
        );
        final contained = (390 / source.width).clamp(0.0, 844 / source.height);
        final imageHeight = source.height * contained;
        final imageWidth = source.width * contained;
        final top = media.localToGlobal(
          Offset((390 - imageWidth) / 2, (844 - imageHeight) / 2),
        );
        final bottom = media.localToGlobal(
          Offset((390 + imageWidth) / 2, (844 + imageHeight) / 2),
        );
        expect(top.dy, greaterThanOrEqualTo(53));
        expect(top.dx, greaterThanOrEqualTo(-1));
        expect(bottom.dy, lessThanOrEqualTo(panelTop + 1));
        expect(bottom.dx, lessThanOrEqualTo(391));
        expect(
          (bottom.dx - top.dx) / (bottom.dy - top.dy),
          closeTo(source.width / source.height, .001),
        );
        if (source == fixture ||
            source == portraitFixture ||
            source == squareFixture) {
          await preview(
            tester,
            '${platform.name}-aspect-${source.width}x${source.height}',
          );
        }
        await tester.tap(find.byTooltip('Info'));
        await tester.pumpAndSettle();
        // A slow drag must follow the finger, not jump to a dimension-specific detent.
        final gesture = await tester.startGesture(const Offset(195, 420));
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
        final before = tester
            .getTopLeft(find.byKey(const ValueKey('viewer-details-surface')))
            .dy;
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        final after = tester
            .getTopLeft(find.byKey(const ValueKey('viewer-details-surface')))
            .dy;
        expect(before - after, closeTo(60, 1));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
    testWidgets('zoomed photo pans without opening inspector $platform', (
      tester,
    ) async {
      await pump(tester, platform, Brightness.dark, portrait: true);
      await tester.tapAt(const Offset(195, 420));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(195, 420));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PhotoViewerStage>(find.byType(PhotoViewerStage))
            .mediaZoomed,
        isTrue,
      );
      await tester.dragFrom(const Offset(195, 420), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<PhotoViewerStageState>(find.byType(PhotoViewerStage))
            .isOpen,
        isFalse,
      );
      final photo = tester
          .widgetList<PhotoView>(find.byType(PhotoView))
          .firstWhere((photo) => photo.controller?.scale != null);
      final scale = photo.controller!.scale;
      final position = photo.controller!.position;
      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Info'));
      await tester.pumpAndSettle();
      expect(photo.controller!.scale, scale);
      expect(photo.controller!.position, position);
      expect(tester.takeException(), isNull);
    });
  }
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'slow drags keep arbitrary positions and handle reversals stay under the finger $platform',
      (tester) async {
        await pump(tester, platform, Brightness.dark);
        final surface = find.byKey(const ValueKey('viewer-details-surface'));
        final gesture = await tester.startGesture(const Offset(195, 420));
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -180));
        await tester.pump();
        final held = tester.getTopLeft(surface).dy;
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(surface).dy, closeTo(held, 1));
        expect(
          held,
          greaterThan(500),
        ); // No forced jump to the old 55% opening.
        for (final dy in [-80.0, 60.0, -110.0, 80.0]) {
          final start = tester.getCenter(
            find.byKey(const ValueKey('viewer-details-handle')),
          );
          final drag = await tester.startGesture(start);
          await drag.moveBy(Offset(0, dy.sign * 25));
          await tester.pump();
          final before = tester.getTopLeft(surface).dy;
          await drag.moveBy(Offset(0, dy));
          await tester.pump();
          expect(tester.getTopLeft(surface).dy - before, closeTo(dy, 1));
          final end = tester.getTopLeft(surface).dy;
          await tester.pump(const Duration(milliseconds: 300));
          await drag.up();
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(surface).dy, closeTo(end, 1));
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'handle can interrupt a fling and collapse scrolled metadata $platform',
      (tester) async {
        await pump(tester, platform, Brightness.dark, scale: 2);
        await tester.tap(find.byTooltip('Info'));
        await tester.pumpAndSettle();
        final handle = find.byKey(const ValueKey('viewer-details-handle'));
        final surface = find.byKey(const ValueKey('viewer-details-surface'));
        await tester.fling(handle, const Offset(0, -280), 2400);
        await tester.pump(const Duration(milliseconds: 40));
        final drag = await tester.startGesture(tester.getCenter(handle));
        await drag.moveBy(const Offset(0, 30));
        await tester.pump();
        final before = tester.getTopLeft(surface).dy;
        await drag.moveBy(const Offset(0, 80));
        await tester.pump();
        expect(tester.getTopLeft(surface).dy, closeTo(before + 80, 1));
        await drag.up();
        await tester.pumpAndSettle();
        await tester.fling(handle, const Offset(0, -500), 2000);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(PhotoDetailsSheet),
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PhotoDetailsSheet>(find.byType(PhotoDetailsSheet))
              .scrollController
              .offset,
          greaterThan(0),
        );
        await tester.drag(handle, const Offset(0, 780));
        await tester.pumpAndSettle();
        expect(
          tester
              .state<PhotoViewerStageState>(find.byType(PhotoViewerStage))
              .isOpen,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('thumbnail scrub updates both selected photo and information', (
    tester,
  ) async {
    await pump(tester, TargetPlatform.android, Brightness.dark);
    await tester.drag(find.byType(PhotoViewerFilmstrip), const Offset(-100, 0));
    await tester.pumpAndSettle();
    final strip = tester.widget<PhotoViewerFilmstrip>(
      find.byType(PhotoViewerFilmstrip),
    );
    expect(strip.index, greaterThan(4));
    expect(
      tester.widget<PhotoDetailsSheet>(find.byType(PhotoDetailsSheet)).file.id,
      files[strip.index].id,
    );
  });
  testWidgets('selection remains attached to identity after list reordering', (
    tester,
  ) async {
    final drive = Drive();
    await pump(tester, TargetPlatform.iOS, Brightness.dark, drive: drive);
    drive.items = drive.items.reversed.toList();
    drive.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PhotoDetailsSheet>(find.byType(PhotoDetailsSheet)).file.id,
      'p4',
    );
    expect(
      tester
          .widget<PhotoViewerFilmstrip>(find.byType(PhotoViewerFilmstrip))
          .index,
      7,
    );
  });
}
