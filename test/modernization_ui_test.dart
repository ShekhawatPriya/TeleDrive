import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_m_fsdk/core/theme/app_theme.dart';

import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';

import 'package:flutter_m_fsdk/features/auth/landing_screen.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photos_grid_view.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photo_grid_density.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photo_tile.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_m_fsdk/features/drive/components/drive_header_widgets.dart';

import 'package:flutter_m_fsdk/features/drive/components/drive_selection_bar.dart';

import 'package:flutter_m_fsdk/features/profile/widgets/storage_donut_card.dart';

import 'package:flutter_m_fsdk/features/search/search_controller.dart';

import 'package:flutter_m_fsdk/models/auth_user.dart';

import 'package:flutter_m_fsdk/widgets/file_list_tile.dart';

import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';

import 'package:flutter_m_fsdk/widgets/teledrive_app_bar.dart';

class _Auth extends ChangeNotifier implements AuthController {
  @override
  AuthUser? get user =>
      const AuthUser(userId: 1, telegramId: 1, firstName: 'Alex');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('preview')),
  );

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);

    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    final file = File('build/modernization/$name.png');

    await file.parent.create(recursive: true);

    await file.writeAsBytes(bytes!.buffer.asUint8List());

    image.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final theme = buildTheme(AppBrand.scheme(brightness));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith((_) => _Auth())],
      child: MaterialApp(
        theme: theme.copyWith(
          platform: platform,
          textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
        ),

        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Portable test fonts; native device validation uses the platform system font.
    for (final family in ['Inter', 'Roboto', '.SF Pro Text']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'navigation fits 320px $platform text $scale and activates every tab',
        (tester) async {
          var destination = -1;

          await _pump(
            tester,
            Scaffold(
              bottomNavigationBar: FloatingPillNavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (index) => destination = index,
              ),
            ),
            width: 320,
            scale: scale,
            platform: platform,
          );

          for (var index = 0; index < driveDestinations.length; index++) {
            await tester.tap(find.text(driveDestinations[index].label));
            await tester.pumpAndSettle();
            expect(destination, index);
          }

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('onboarding stays usable at large text', (tester) async {
    await _pump(tester, const LandingScreen(), width: 320, scale: 2);

    await tester.scrollUntilVisible(find.text('Continue with Telegram'), 200);

    expect(tester.takeException(), isNull);
  });

  testWidgets('selection actions wrap and remain reachable', (tester) async {
    var deleted = false;

    await _pump(
      tester,
      Scaffold(
        body: DriveSelectionBar(
          selectedCount: 120,
          onCancel: () {},
          onShare: () {},
          onStar: () {},
          onMove: () {},
          onDelete: () => deleted = true,
        ),
      ),
      width: 320,
      scale: 2,
    );

    await tester.tap(find.text('Delete'));
    expect(deleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage breakdown supports large text', (tester) async {
    await _pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: StorageDonutCard(
            used: 1073741824,
            categories: [
              StorageCategory(
                label: 'Documents',
                bytes: 1073741824,
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
      width: 320,
      scale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a thousand photos build only the visible tiles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final density = PhotoGridDensity();
    addTearDown(density.dispose);
    final files = List.generate(
      1000,
      (index) => DriveFile(
        id: '$index',
        name: 'photo-$index.jpg',
        kind: FileKind.image,
        size: 10,
        modifiedAt: '2026-09-16',
        createdAt: '2026-09-16',
        parentId: null,
        starred: false,
      ),
    );
    await _pump(
      tester,
      Scaffold(
        body: PhotosGridView(
          files: files,
          density: density,
          onLoadMore: () {},
          loadingMore: false,
          selectMode: false,
          selectedIds: const {},
          onTileTap: (_) {},
          onTileLongPress: (_, _) {},
          onTilePanSelect: (_) {},
        ),
      ),
    );
    expect(find.byType(PhotoTile).evaluate().length, lessThan(60));
    expect(tester.takeException(), isNull);
    await _preview(tester, 'photos-layout');
  });
  testWidgets('header and file rows fit a small phone at large text', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            const TeleDriveTopBar(scope: SearchScope.drive),
            Expanded(
              child: ListView(
                children: [
                  FileListTile(
                    name: 'A long folder name',
                    subtitle: '12 files',
                    isFolder: true,
                    onTap: () {},
                    onStar: () {},
                    onMore: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      width: 320,
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('drive components render in $brightness', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Column(
            children: [
              const TeleDriveTopBar(scope: SearchScope.drive),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: DriveQuickActions(
                        onTrashTap: () {},
                        onArchiveTap: () {},
                        onLockedTap: () {},
                      ),
                    ),

                    const DriveSectionHeader('Folders'),

                    SliverList.list(
                      children: [
                        for (final name in ['Personal', 'Projects', 'Travel'])
                          FileListTile(
                            name: name,
                            subtitle: '12 files · 24 MB',
                            isFolder: true,
                            onTap: () {},
                            onStar: () {},
                            onMore: () {},
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          bottomNavigationBar: FloatingPillNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
        brightness: brightness,
      );

      expect(tester.takeException(), isNull);

      await _preview(tester, 'drive-${brightness.name}');
    });

    testWidgets('welcome renders in $brightness', (tester) async {
      await _pump(tester, const LandingScreen(), brightness: brightness);

      expect(tester.takeException(), isNull);

      await _preview(tester, 'welcome-${brightness.name}');
    });
  }
}
