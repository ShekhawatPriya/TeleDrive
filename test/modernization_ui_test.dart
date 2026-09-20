import 'package:flutter/cupertino.dart';
import 'package:flutter_m_fsdk/features/photos/components/photo_library_cover.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m_fsdk/features/profile/legal_screen.dart';
import 'package:flutter_m_fsdk/features/project/changelog_screen.dart';
import 'package:flutter_m_fsdk/features/project/github_release_models.dart';
import 'package:flutter_m_fsdk/features/profile/gallery_backup_controller.dart';
import 'package:flutter_m_fsdk/features/project/project_screen.dart';
import 'package:flutter_m_fsdk/features/project/changelog_controller.dart';
import 'package:flutter_m_fsdk/widgets/file_card_tile.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_action_sheet.dart';
import 'package:flutter_m_fsdk/features/profile/my_data_screen.dart';
import 'package:flutter_m_fsdk/features/profile/profile_screen.dart';
import 'package:flutter_m_fsdk/features/profile/free_up_space_screen.dart';
import 'package:flutter_m_fsdk/features/profile/free_up_space/free_up_space_controller.dart';
import 'package:flutter_m_fsdk/widgets/account_button.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/features/profile/widgets/account_bottom_sheet.dart';
import 'package:flutter_m_fsdk/features/profile/settings_screen.dart';
import 'package:flutter_m_fsdk/features/profile/storage_summary_controller.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/profile/cache_controller.dart';
import 'package:flutter_m_fsdk/core/network/backend_resolver.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
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
import 'package:flutter_m_fsdk/widgets/item_status_indicators.dart';

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
    widthPx: i % 3 == 0 ? 3024 : (i % 3 == 1 ? 4032 : 5000),
    heightPx: i % 3 == 0 ? 4032 : (i % 3 == 1 ? 3024 : 2200),
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

class _DesignFreeSpace extends ChangeNotifier implements FreeUpSpaceController {
  @override
  FreeUpSpaceState get state => const FreeUpSpaceState();
  @override
  Future<void> scan() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DesignCache extends CacheController {
  @override
  Future<void> refreshCacheStats() async {}
}

class _DesignStorage extends ChangeNotifier
    implements StorageSummaryController {
  @override
  StorageSummary? get value => StorageSummary.empty;
  @override
  Future<void> ensureLoaded({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DesignBackup extends ChangeNotifier implements GalleryBackupController {
  @override
  GalleryBackupDiagnostics get diagnostics => const GalleryBackupDiagnostics();
  @override
  bool get running => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DesignChangelog extends ChangeNotifier implements ChangelogController {
  @override
  ChangelogState get state => ChangelogState(
    hasLoadedOnce: true,
    releases: [
      GithubRelease(
        tagName: 'v2.1.10',
        title: 'TeleDrive 2.1.10',
        body:
            '## Improvements\n- Clearer settings and navigation.\n- Improved photo backup controls.',
        htmlUrl: 'https://github.com/example/releases',
        publishedAt: DateTime(2026, 9, 17),
      ),
    ],
  );
  @override
  Future<void> load({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DesignSettings extends ChangeNotifier implements AppSettingsController {
  @override
  AppSettingsState state = const AppSettingsState(loaded: true);
  @override
  Future<void> setUploadOnMobileData(bool value) async {
    state = state.copyWith(uploadOnMobileData: value);
    notifyListeners();
  }

  @override
  Future<void> setGalleryBackupEnabled(bool value) async {
    state = state.copyWith(galleryBackupEnabled: value);
    notifyListeners();
  }

  @override
  Future<void> setGalleryBackupScanLimit(int value) async {
    state = state.copyWith(galleryBackupScanLimit: value);
    notifyListeners();
  }

  @override
  Future<void> setGalleryBackupQueueLimit(int value) async {
    state = state.copyWith(galleryBackupQueueLimit: value);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DesignBackend extends ChangeNotifier implements BackendResolver {
  @override
  BackendStatus get status => BackendStatus.connected;
  @override
  String get sourceLabel => "Automatic connection";
  @override
  String get baseUrl => "https://teledrive.example.com";
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Auth extends ChangeNotifier implements AuthController {
  @override
  AccountVault get vault => const AccountVault.empty();
  @override
  bool? get telegramConnected => true;
  @override
  int get largeUploadThresholdBytes => 100 * 1024 * 1024;
  @override
  Future<void> refreshProfile() async {}
  @override
  Future<void> refreshSavedAccountSnapshots() async {}

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

GoRouter _accountRouter(Widget home) => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => home),
    GoRoute(
      path: '/account',
      pageBuilder: (_, state) =>
          CupertinoPage(key: state.pageKey, child: const AccountBottomSheet()),
    ),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/profile/my-data', builder: (_, __) => const MyDataScreen()),
    GoRoute(
      path: '/profile/free-up-space',
      builder: (_, __) => const FreeUpSpaceScreen(),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  GoRouter? router,
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
        galleryBackupControllerProvider.overrideWith((_) => _DesignBackup()),
        changelogControllerProvider.overrideWith((_) => _DesignChangelog()),
        authControllerProvider.overrideWith((_) => _Auth()),
        storageSummaryControllerProvider.overrideWith((_) => _DesignStorage()),
        appSettingsControllerProvider.overrideWith((_) => _DesignSettings()),
        backendResolverProvider.overrideWith((_) => _DesignBackend()),
        cacheControllerProvider.overrideWith((_) => _DesignCache()),
        freeUpSpaceControllerProvider.overrideWith((_) => _DesignFreeSpace()),
        driveControllerProvider.overrideWith((_) => _DesignDrive()),
        driveSearchProvider.overrideWith((_) => _DesignSearch()),
        shareControllerProvider.overrideWith((_) => _DesignShares()),
      ],
      child: router != null
          ? MaterialApp.router(
              routerConfig: router,
              theme: theme.copyWith(
                platform: platform,
                textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
              ),
            )
          : MaterialApp(
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
                child: RepaintBoundary(
                  key: const ValueKey('preview'),
                  child: child,
                ),
              ),
            ),
    ),
  );

  if (child is ProjectScreen) {
    await tester.runAsync(() async {
      final context = tester.element(find.byType(ProjectScreen));
      await precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        context,
      );
      await precacheImage(
        const AssetImage('assets/icon/devsdocode.png'),
        context,
      );
    });
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: "");
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
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
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
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
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
  testWidgets('drive scroll dismisses the search keyboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, _tabPreview(SearchScope.drive, const DriveScreen()));
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS search cancel fits a small phone with large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(
      tester,
      _tabPreview(SearchScope.drive, const DriveScreen()),
      width: 320,
      scale: 2,
    );
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cancel search'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cancel search'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'dedicated account page follows appearance changes without a close button',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const home = Scaffold(body: Center(child: AccountButton()));
      final router = _accountRouter(home);
      addTearDown(router.dispose);
      await _pump(tester, home, brightness: Brightness.dark, router: router);
      await tester.tap(find.byType(AccountButton));
      await tester.pumpAndSettle();
      expect(find.byType(AccountBottomSheet), findsOneWidget);
      await _pump(tester, home, brightness: Brightness.light, router: router);
      final sheet = find.descendant(
        of: find.byType(AccountBottomSheet),
        matching: find.byType(Scaffold),
      );
      final theme = Theme.of(tester.element(sheet));
      expect(theme.brightness, Brightness.light);
      expect(
        tester.widget<Scaffold>(sheet).backgroundColor,
        theme.colorScheme.surface,
      );
      expect(theme.colorScheme.surface.computeLuminance(), greaterThan(.8));
      expect(find.byTooltip('Close'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountBottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Settings back returns to the dedicated Account page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const home = Scaffold(body: Center(child: AccountButton()));
    final router = _accountRouter(home);
    addTearDown(router.dispose);
    await _pump(tester, home, router: router);
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountBottomSheet), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final destination in [
    ('Telegram Drive', ProfileScreen),
    ('Free Up Space', FreeUpSpaceScreen),
    ('My Data', MyDataScreen),
  ]) {
    testWidgets('${destination.$1} Back retains Account underneath', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      const home = Scaffold(body: Center(child: AccountButton()));
      final router = _accountRouter(home);
      addTearDown(router.dispose);
      await _pump(tester, home, router: router);
      await tester.tap(find.byType(AccountButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(destination.$1),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(destination.$1));
      await tester.pumpAndSettle();
      expect(find.byType(destination.$2), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountBottomSheet), findsOneWidget);
      expect(router.canPop(), isTrue);
      expect(find.byTooltip('Close'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'random photo highlights swipe without making the latest primary',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(
        tester,
        _tabPreview(SearchScope.photos, const PhotosScreen()),
      );
      final covers = find.byType(PhotoLibraryCover);
      final first = tester.widget<PhotoLibraryCover>(covers.first).file.id;
      expect(first, isNot(_media.first.id));
      final pager = find.byKey(const ValueKey('photo-highlights'));
      await tester.drag(pager, const Offset(-350, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Highlight 2 of 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('separate search cancel $platform $brightness $scale', (
          tester,
        ) async {
          await _pump(
            tester,
            const Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: DriveSearchField(scope: SearchScope.drive),
                ),
              ),
            ),
            platform: platform,
            brightness: brightness,
            width: scale == 2 ? 320 : 390,
            scale: scale,
            highContrast: scale == 2,
            reduceEffects: scale == 2,
          );
          await tester.enterText(find.byType(EditableText), 'Summer');
          await tester.pumpAndSettle();
          final field = tester.getRect(find.byType(TextField));
          final cancel = tester.getRect(find.byTooltip('Cancel search'));
          expect(cancel.left - field.right, greaterThanOrEqualTo(8));
          expect(cancel.shortestSide, greaterThanOrEqualTo(48));
          expect(find.text('Done'), findsNothing);
          await _preview(
            tester,
            'search-${platform.name}-${brightness.name}-$scale',
          );
          await tester.tap(find.byTooltip('Cancel search'));
          await tester.pump(const Duration(milliseconds: 120));
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.testTextInput.isVisible, isFalse);
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            isEmpty,
          );
        });
      }
    }
  }
  testWidgets('backup controls update settings and keep limits bounded', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const BackupSettingsScreen());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupSettingsScreen)),
    );
    final settings =
        container.read(appSettingsControllerProvider) as _DesignSettings;
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(settings.state.galleryBackupEnabled, isTrue);
    await tester.tap(find.bySemanticsLabel('Increase Items per Scan'));
    await tester.pumpAndSettle();
    expect(settings.state.galleryBackupScanLimit, 90);
    await settings.setGalleryBackupScanLimit(499);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Increase Items per Scan'));
    await tester.pumpAndSettle();
    expect(settings.state.galleryBackupScanLimit, 500);
    await tester.tap(find.bySemanticsLabel('Decrease Queued Uploads'));
    await tester.pumpAndSettle();
    expect(settings.state.galleryBackupQueueLimit, 10);
    expect(tester.takeException(), isNull);
  });
  testWidgets('backup scan report opens and stays readable at large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const BackupSettingsScreen(), width: 320, scale: 2);
    await tester.scrollUntilVisible(
      find.text('Scan Report'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Scan Report'));
    await tester.pumpAndSettle();
    expect(find.text('Items Found'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(BackupSettingsScreen), findsOneWidget);
  });
  for (final dark in [false, true]) {
    testWidgets('Android shared starred indicators stay separate dark=$dark', (
      tester,
    ) async {
      var opened = 0;
      var menus = 0;
      var starred = 0;
      const folder = DriveFolder(
        id: 'both',
        name: 'Shared project files',
        parentId: null,
        createdAt: '2026-09-18',
        modifiedAt: '2026-09-18',
        starred: true,
        shared: true,
        recursiveFileCount: 6,
        recursiveSize: 22000000,
      );
      await _pump(
        tester,
        Scaffold(
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 134,
                    height: 176,
                    child: FolderCollectionCard(
                      folder: folder,
                      onTap: () => opened++,
                      onLongPress: () {},
                      onMore: () => menus++,
                    ),
                  ),
                ),
              ),
              FileListTile(
                name: folder.name,
                subtitle: '6 files · 22 MB',
                isFolder: true,
                starred: true,
                shared: true,
                onTap: () => opened++,
                onStar: () => starred++,
                onMore: () => menus++,
              ),
            ],
          ),
        ),
        platform: TargetPlatform.android,
        width: 320,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
      final marker = find.descendant(
        of: find.byType(FolderCollectionCard),
        matching: find.byType(ItemStatusIndicators),
      );
      final icon = find.byIcon(Icons.folder_shared_rounded);
      final menu = find.byTooltip('Actions for ${folder.name}').first;
      expect(tester.getRect(marker).overlaps(tester.getRect(icon)), isFalse);
      expect(tester.getRect(marker).overlaps(tester.getRect(menu)), isFalse);
      expect(tester.getSize(menu).shortestSide, greaterThanOrEqualTo(48));
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.link_rounded), findsNWidgets(2));
      await tester.tap(menu);
      await tester.tap(find.byTooltip('Unstar ${folder.name}'));
      await tester.tap(find.text(folder.name).last);
      expect(menus, 1);
      expect(starred, 1);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      await _preview(tester, 'android-item-status-$dark');
    });
  }
  for (final page in <(String, Widget)>[
    ('settings', const SettingsScreen()),
    ('server', const ServerConnectionSettingsScreen()),
    ('uploads', const UploadSettingsScreen()),
    ('backup', const BackupSettingsScreen()),
    ('cache', const CacheStorageSettingsScreen()),
    ('privacy', const PrivacySecuritySettingsScreen()),
    ('notifications', const NotificationsSettingsScreen()),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Android expressive ${page.$1} dark=$dark scale=$scale', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          await _pump(
            tester,
            page.$2,
            platform: TargetPlatform.android,
            brightness: dark ? Brightness.dark : Brightness.light,
            width: scale == 1 ? 390 : 320,
            scale: scale,
            highContrast: scale == 2,
          );
          await _preview(tester, 'android-${page.$1}-$dark-$scale-top');
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 4; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await _preview(tester, 'android-${page.$1}-$dark-$scale-bottom');
        });
      }
    }
  }
  testWidgets('Android upload switch persists through row and control taps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(
      tester,
      const UploadSettingsScreen(),
      platform: TargetPlatform.android,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UploadSettingsScreen)),
    );
    final settings =
        container.read(appSettingsControllerProvider) as _DesignSettings;
    final before = settings.state.uploadOnMobileData;
    await tester.ensureVisible(find.text('Upload on Mobile Data'));
    await tester.tap(find.text('Upload on Mobile Data'));
    await tester.pumpAndSettle();
    expect(settings.state.uploadOnMobileData, !before);
    final row = find
        .ancestor(
          of: find.text('Upload on Mobile Data'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(settings.state.uploadOnMobileData, before);
  });
  for (final page in <(String, Widget)>[
    ('server', const ServerConnectionSettingsScreen()),
    ('uploads', const UploadSettingsScreen()),
    ('backup', const BackupSettingsScreen()),
    ('cache', const CacheStorageSettingsScreen()),
    ('privacy', const PrivacySecuritySettingsScreen()),
    ('notifications', const NotificationsSettingsScreen()),
    ('about', const ProjectScreen()),
    ('releases', const ChangelogScreen()),
    ('legal-privacy', const LegalScreen(kind: LegalKind.privacy)),
    ('legal-terms', const LegalScreen(kind: LegalKind.terms)),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('settings detail ${page.$1} dark=$dark scale=$scale', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          await _pump(
            tester,
            page.$2,
            width: scale == 1 ? 390 : 320,
            scale: scale,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          await _preview(tester, 'detail-${page.$1}-$dark-$scale-top');
          expect(tester.takeException(), isNull);
          final scroll = find.byType(Scrollable).first;
          for (var i = 0; i < 4; i++) {
            await tester.drag(scroll, const Offset(0, -600));
            await tester.pumpAndSettle();
            await _preview(tester, 'detail-${page.$1}-$dark-$scale-scroll-$i');
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Android project page adapts ${brightness.name} scale=$scale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await _pump(
            tester,
            const ProjectScreen(),
            width: scale == 1 ? 390 : 320,
            scale: scale,
            brightness: brightness,
            platform: TargetPlatform.android,
          );

          expect(find.text('TeleDrive'), findsOneWidget);
          expect(
            find.image(const AssetImage('assets/icon/app_icon.png')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _preview(
            tester,
            'android-project-${brightness.name}-$scale-top',
          );

          final scroll = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(
            find.text('Made by Sree'),
            420,
            scrollable: scroll,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('project-social-youtube')),
            280,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();

          expect(
            find.image(const AssetImage('assets/icon/devsdocode.png')),
            findsOneWidget,
          );
          final socialKeys = <ValueKey<String>>[
            const ValueKey('project-social-github'),
            const ValueKey('project-social-instagram'),
            const ValueKey('project-social-x'),
            const ValueKey('project-social-youtube'),
          ];
          final rects = socialKeys
              .map((key) => tester.getRect(find.byKey(key)))
              .toList();
          for (final rect in rects) {
            expect(rect.height, greaterThanOrEqualTo(48));
          }
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse);
            }
          }
          expect(rects[2].width, lessThan(rects[1].width));
          expect(find.text('Instagram'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Made by Sree'),
            -280,
            scrollable: scroll,
          );
          await tester.pumpAndSettle();
          await _preview(
            tester,
            'android-project-${brightness.name}-$scale-maker',
          );
        },
      );
    }
  }
  for (final page in <(String, Widget)>[
    ('storage', const ProfileScreen()),
    ('my-data', const MyDataScreen()),
    ('free-space', const FreeUpSpaceScreen()),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('iOS ${page.$1} fits at text $scale', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await _pump(
          tester,
          page.$2,
          width: scale == 1 ? 390 : 320,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        await _preview(tester, 'ios-${page.$1}-$scale');
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'account and settings fit small iPhone ${brightness.name} $scale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await _pump(
            tester,
            const Scaffold(body: AccountBottomSheet()),
            width: scale == 1 ? 390 : 320,
            scale: scale,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Alex'), findsOneWidget);
          await _preview(tester, 'account-${brightness.name}-$scale');
          await tester.drag(
            find.byType(CustomScrollView).first,
            const Offset(0, -650),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _pump(
            tester,
            const SettingsScreen(),
            width: scale == 1 ? 390 : 320,
            scale: scale,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          await _preview(tester, 'settings-${brightness.name}-$scale');
        },
      );
    }
  }
  testWidgets(
    'photo viewer toolbar actions remain reachable on a small phone',
    (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              PhotoViewerTopBar(
                file: _media.first,
                visible: true,
                onBack: () => calls.add('Back'),
                onStar: () => calls.add('Remove star'),
                onInfo: () => calls.add('Info'),
                onDownload: () => calls.add('Download'),
                onMore: () => calls.add('More'),
              ),
              const Spacer(),
              PhotoViewerActions(
                file: _media.first,
                onStar: () => calls.add('Remove star'),
                onInfo: () => calls.add('Info'),
                onDownload: () => calls.add('Download'),
              ),
            ],
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
  for (final brightness in Brightness.values) {
    testWidgets('dense iOS files and opaque actions in ${brightness.name}', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: ListView(
            children: [
              for (final file in _media)
                FileListTile(
                  name: file.name,
                  subtitle: '',
                  file: file,
                  starred: file.starred,
                  onTap: () {},
                  onMore: () {},
                  onStar: () {},
                ),
            ],
          ),
        ),
        brightness: brightness,
      );
      expect(
        tester.getSize(find.byType(FileListTile).first).height,
        lessThanOrEqualTo(76),
      );
      expect(find.textContaining('JPG · 2.3 MB · 14 Sep 2026'), findsWidgets);
      expect(tester.takeException(), isNull);
      await _preview(tester, 'ios-file-list-${brightness.name}');
      await _pump(
        tester,
        Scaffold(
          body: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: .72,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            padding: const EdgeInsets.all(20),
            children: [
              for (final file in _media.take(4))
                FileCardTile(file: file, onTap: () {}, onMore: () {}),
            ],
          ),
        ),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _preview(tester, 'ios-file-grid-${brightness.name}');
      await _pump(
        tester,
        Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.blue)),
              Align(
                alignment: Alignment.bottomCenter,
                child: AdaptiveSurface(
                  child: DriveActionSheet(
                    title: 'Summer photos',
                    folder: _folders.first,
                    actions: const [
                      SheetActionItem(
                        id: 'share',
                        label: 'Share',
                        icon: Icons.share,
                      ),
                      SheetActionItem(
                        id: 'star',
                        label: 'Star',
                        icon: Icons.star,
                      ),
                      SheetActionItem(
                        id: 'rename',
                        label: 'Rename',
                        icon: Icons.edit,
                      ),
                      SheetActionItem(
                        id: 'move',
                        label: 'Move',
                        icon: Icons.folder,
                      ),
                      SheetActionItem(
                        id: 'delete',
                        label: 'Delete',
                        icon: Icons.delete,
                        destructive: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        brightness: brightness,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
      await _preview(tester, 'ios-item-sheet-${brightness.name}');
      await _pump(
        tester,
        Scaffold(
          body: ShareDetailBody(
            share: _shares.first,
            stats: null,
            accesses: const [],
            accessesLoading: false,
            accessesHasMore: false,
            onLoadMore: () {},
            onCopy: () {},
            onShare: () {},
          ),
        ),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _preview(tester, 'ios-share-${brightness.name}');
    });
  }
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
      const Scaffold(
        body: AdaptiveSurface(
          role: GlassRole.navigation,
          child: Text('Controls'),
        ),
      ),
      reduceEffects: false,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
  testWidgets('glass has an opaque fallback when high contrast is requested', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: AdaptiveSurface(child: Text('Controls'))),
      highContrast: true,
    );
    expect(find.byType(BackdropFilter), findsNothing);
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

  testWidgets('Android selection actions wrap and remain reachable', (
    tester,
  ) async {
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
      platform: TargetPlatform.android,
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
