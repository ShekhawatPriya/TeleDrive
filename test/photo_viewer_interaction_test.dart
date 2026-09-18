import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
          ImageInfo(image: (portrait ? portraitFixture : fixture).clone()),
        ),
      ),
    );
  }
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(AppBrand.scheme(brightness));
  debugDefaultTargetPlatformOverride = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driveControllerProvider.overrideWith((_) => drive ?? Drive()),
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
      final panelTop = tester.getTopLeft(find.byType(PhotoDetailsSheet)).dy;
      expect(panelTop, closeTo(390 * fixture.height / fixture.width, 1));
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
