import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

import 'package:flutter_m_fsdk/features/drive/drive_screen.dart';
import 'package:flutter_m_fsdk/features/drive/starred_screen.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/search/drive_search_controller.dart';
import 'package:flutter_m_fsdk/features/photos/photos_screen.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_details_sheet.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_top_bar.dart';
import 'package:flutter_m_fsdk/features/share/my_shares_screen.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/features/share/components/share_detail_body.dart';
import 'package:flutter_m_fsdk/features/file_viewer/components/metadata_block.dart';
import 'package:flutter_m_fsdk/models/share_models.dart';
import 'package:flutter_m_fsdk/widgets/adaptive_surface.dart';
import 'package:flutter_m_fsdk/widgets/folder_collection_card.dart';

final _fixturePath = File('test/fixtures/design/alpine.jpg').absolute.path;
late ui.Image _fixtureImage;
final _media = List.generate(
  9,
  (i) => DriveFile(
    id: 'image-$i',
    name: i == 0 ? 'A weekend in the mountains.jpg' : 'Alpine afternoon $i.jpg',
    kind: i == 8 ? FileKind.video : FileKind.image,
    size: 2450000,
    mimeType: i == 8 ? 'video/mp4' : 'image/jpeg',
    modifiedAt: '2026-09-14T12:30:00Z',
    createdAt: '2026-09-14T12:30:00Z',
    parentId: null,
    starred: true,
    thumbnailUrl: _fixturePath,
    widthPx: 4032,
    heightPx: 3024,
  ),
);
const _folders = [
  DriveFolder(
    id: 'f1',
    name: 'Everyday essentials',
    parentId: null,
    modifiedAt: '2026-09-14',
    createdAt: '2026-09-14',
    recursiveFileCount: 12,
    recursiveSize: 42000000,
  ),
  DriveFolder(
    id: 'f2',
    name: 'Places to remember',
    parentId: null,
    modifiedAt: '2026-09-14',
    createdAt: '2026-09-14',
    recursiveFileCount: 24,
    recursiveSize: 128000000,
  ),
];
final _shares = [
  Share(
    id: 's1',
    token: 'fixture',
    url: 'https://example.com/share/fixture',
    permission: SharePermission.preview,
    createdAt: DateTime(2026, 9, 14),
    viewCount: 28,
    downloadCount: 0,
    items: const [],
    primaryName: 'Our mountain weekend',
    itemCount: 12,
  ),
  Share(
    id: 's2',
    token: 'fixture',
    url: 'https://example.com/share/fixture',
    permission: SharePermission.download,
    createdAt: DateTime(2026, 9, 14),
    expiresAt: DateTime(2020),
    viewCount: 7,
    downloadCount: 3,
    items: const [],
    primaryName: 'Project handover',
    itemCount: 4,
  ),
];

class _DesignDrive extends ChangeNotifier implements DriveController {
  @override
  DriveState state = const DriveState();
  @override
  List<DriveFolder> get folders => _folders;
  @override
  List<DriveFile> photoFiles(String filter) => _media;
  @override
  DriveFolderViewSnapshot folderViewSnapshot(String? folderId) =>
      DriveFolderViewSnapshot(
        folderId: folderId,
        folder: null,
        folders: _folders,
        files: _media,
        path: const [],
        loaded: true,
        loading: false,
        loadingMore: false,
        hasMore: false,
        error: null,
      );
  @override
  DriveStarredSnapshot starredSnapshot() => DriveStarredSnapshot(
    files: _media.take(2).toList(),
    folders: const [],
    loaded: true,
    loading: false,
    loadingMore: false,
    hasMore: false,
    error: null,
  );
  @override
  DriveRecentsSnapshot recentsSnapshot() =>
      DriveRecentsSnapshot(_media.take(3).toList());
  @override
  Future<void> ensureStarredLoaded({bool force = false}) async {}
  @override
  Future<void> refresh({bool silent = false, bool force = false}) async {}
  @override
  Future<void> loadMoreMedia() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DesignSearch extends ChangeNotifier implements DriveSearchController {
  @override
  String? get error => null;
  @override
  bool get loading => false;
  @override
  bool get loaded => true;
  @override
  List<DriveFile> get files => _media;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DesignShares extends ChangeNotifier implements ShareController {
  @override
  List<Share> get shares => _shares;
  @override
  bool get loading => false;
  @override
  String? get error => null;
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _tabPreview(SearchScope scope, Widget screen) => Scaffold(
  extendBody: true,
  body: Column(
    children: [
      TeleDriveTopBar(scope: scope),
      Expanded(child: screen),
    ],
  ),
  bottomNavigationBar: FloatingPillNavigationBar(
    selectedIndex: scope.index,
    onDestinationSelected: (_) {},
  ),
);

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
  bool reduceEffects = true,
  bool highContrast = false,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(
    AppBrand.scheme(brightness, highContrast: highContrast),
  );
  debugDefaultTargetPlatformOverride = null;

  for (final width in [320, 640, 960]) {
    final imageKey = await ResizeImage(
      FileImage(File(_fixturePath)),
      width: width,
    ).obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      imageKey,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: _fixtureImage.clone())),
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => _Auth()),
        driveControllerProvider.overrideWith((_) => _DesignDrive()),
        driveSearchProvider.overrideWith((_) => _DesignSearch()),
        shareControllerProvider.overrideWith((_) => _DesignShares()),
      ],
      child: MaterialApp(
        theme: theme.copyWith(
          platform: platform,
          textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
        ),

        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceEffects,
            highContrast: highContrast,
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
    final codec = await ui.instantiateImageCodec(
      File(_fixturePath).readAsBytesSync(),
    );
    _fixtureImage = (await codec.getNextFrame()).image;
    codec.dispose();
    // Portable test fonts; native device validation uses the platform system font.
    for (final family in [
      'Inter',
      'Roboto',
      '.SF Pro Text',
      'JetBrains Mono',
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            family == 'JetBrains Mono'
                ? 'assets/fonts/JetBrainsMono-Variable.ttf'
                : 'assets/fonts/Inter-Variable.ttf',
          ),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  tearDownAll(() => _fixtureImage.dispose());

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      for (final entry in <(SearchScope, Widget)>[
        (SearchScope.drive, const DriveScreen()),
        (SearchScope.photos, const PhotosScreen()),
        (SearchScope.starred, const StarredScreen()),
        (SearchScope.shared, const MySharesScreen()),
      ]) {
        testWidgets('complete ${entry.$1.name} $platform $brightness', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          await _pump(
            tester,
            _tabPreview(entry.$1, entry.$2),
            platform: platform,
            brightness: brightness,
            reduceEffects: false,
          );
          expect(tester.takeException(), isNull);
          await _preview(
            tester,
            'full-${entry.$1.name}-${platform.name}-${brightness.name}',
          );
        });
      }
    }
  }
  for (final entry in <(SearchScope, Widget)>[
    (SearchScope.drive, const DriveScreen()),
    (SearchScope.photos, const PhotosScreen()),
    (SearchScope.starred, const StarredScreen()),
    (SearchScope.shared, const MySharesScreen()),
  ]) {
    testWidgets(
      'complete ${entry.$1.name} small phone large text high contrast',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await _pump(
          tester,
          _tabPreview(entry.$1, entry.$2),
          width: 320,
          scale: 2,
          highContrast: true,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'photo viewer toolbar actions remain reachable on a small phone',
    (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        Scaffold(
          backgroundColor: Colors.black,
          body: PhotoViewerTopBar(
            file: _media.first,
            visible: true,
            onBack: () => calls.add('Back'),
            onStar: () => calls.add('Remove star'),
            onInfo: () => calls.add('Info'),
            onDownload: () => calls.add('Download'),
            onMore: () => calls.add('More'),
          ),
        ),
        width: 320,
      );
      for (final name in ['Back', 'Remove star', 'Download', 'Info', 'More']) {
        await tester.tap(find.byTooltip(name));
      }
      expect(calls.length, 5);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'photos filter changes the visible collection and restores all media',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, const PhotosScreen());
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoTile), findsOneWidget);
      expect(
        tester.widget<PhotoTile>(find.byType(PhotoTile)).file.kind,
        FileKind.video,
      );
      await tester.tap(find.text('All media'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoTile).evaluate().length, greaterThan(1));
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('photo details and share controls fit 320px at $scale', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        Scaffold(
          body: PhotoDetailsSheet(
            file: _media.first,
            folderName: 'Places to remember',
            scrollController: scroll,
          ),
        ),
        width: 320,
        scale: scale,
      );
      expect(find.text('File size'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _preview(tester, 'details-$scale');
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      var copied = false;
      var shared = false;
      await _pump(
        tester,
        Scaffold(
          body: ShareDetailBody(
            share: _shares.first,
            stats: null,
            accesses: const [],
            accessesHasMore: false,
            accessesLoading: false,
            onLoadMore: () {},
            onCopy: () => copied = true,
            onShare: () => shared = true,
          ),
        ),
        width: 320,
        scale: scale,
      );
      await tester.tap(find.text('Copy link'));
      await tester.tap(find.text('Share'));
      expect(copied && shared, isTrue);
      expect(tester.takeException(), isNull);
      await _preview(tester, 'share-details-$scale');
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'folder spacing ${platform.name} ${brightness.name} at $scale',
          (tester) async {
            final examples = [
              _folders.first.copyWith(
                name: 'sm',
                recursiveFileCount: 5,
                recursiveSize: 22020096,
              ),
              _folders.first.copyWith(
                name: 'wo',
                recursiveFileCount: 4,
                recursiveSize: 12582912,
              ),
              _folders.first.copyWith(name: 'Everyday essentials'),
              _folders.first.copyWith(
                name: 'Trips with friends and family',
                starred: true,
              ),
              _folders.first.copyWith(
                name: 'Shared photos',
                shared: true,
                recursiveFileCount: 1,
              ),
              _folders.first.copyWith(name: 'New folder', isOptimistic: true),
            ];
            await _pump(
              tester,
              Scaffold(
                body: SafeArea(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisExtent: 170,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: examples.length,
                    itemBuilder: (_, index) => FolderCollectionCard(
                      folder: examples[index],
                      onTap: () {},
                      onLongPress: () {},
                      onMore: () {},
                    ),
                  ),
                ),
              ),
              platform: platform,
              brightness: brightness,
              width: scale == 1 ? 390 : 320,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            for (final element
                in find.byType(FolderCollectionCard).evaluate()) {
              expect(tester.getSize(find.byWidget(element.widget)).height, 170);
            }
            await _preview(
              tester,
              'folder-spacing-${platform.name}-${brightness.name}-$scale',
            );
          },
        );
      }
    }
  }
  testWidgets('folder card opens and exposes actions independently', (
    tester,
  ) async {
    var opened = 0;
    var actions = 0;
    await _pump(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 170,
            height: 170,
            child: FolderCollectionCard(
              folder: _folders.first,
              onTap: () => opened++,
              onMore: () => actions++,
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(_folders.first.name));
    await tester.tap(find.byTooltip('Actions for ${_folders.first.name}'));
    expect(opened, 1);
    expect(actions, 1);
  });
  testWidgets('metadata is readable at large text', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: MetadataBlock(file: _media.first)),
      ),
      width: 320,
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('iOS floating controls use glass when effects are enabled', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: AdaptiveSurface(child: Text('Controls'))),
      reduceEffects: false,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
  testWidgets(
    'glass has an opaque fallback when accessibility requests reduced effects',
    (tester) async {
      await _pump(
        tester,
        const Scaffold(body: AdaptiveSurface(child: Text('Controls'))),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );
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
