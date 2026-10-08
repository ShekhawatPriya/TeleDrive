// iOS browsing surfaces: Drive home, folders, Starred, Shared and the
// Archive, Locked and Trash spaces. Run with
// --dart-define=WRITE_UI_PREVIEWS=true to write build/modernization/ios-browse-*.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/drive/drive_screen.dart';
import 'package:flutter_m_fsdk/features/drive/folder_screen.dart';
import 'package:flutter_m_fsdk/features/drive/starred_screen.dart';
import 'package:flutter_m_fsdk/features/drive/view_preferences_controller.dart';
import 'package:flutter_m_fsdk/features/profile/archive_screen.dart';
import 'package:flutter_m_fsdk/features/profile/locked_screen.dart';
import 'package:flutter_m_fsdk/features/profile/trash_screen.dart';
import 'package:flutter_m_fsdk/features/search/drive_search_controller.dart';
import 'package:flutter_m_fsdk/features/search/search_controller.dart';
import 'package:flutter_m_fsdk/features/share/my_shares_screen.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/models/share_models.dart';
import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';
import 'package:flutter_m_fsdk/widgets/ios/ios_browse.dart';
import 'package:flutter_m_fsdk/widgets/native_glass_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'platform_folder_ui_test.dart' show capture;

final _image = File('test/fixtures/design/alpine.jpg').absolute.path;
late ui.Image _decoded;

DriveFile _file(
  String id,
  String name,
  FileKind kind,
  int size, {
  bool starred = false,
  bool shared = false,
  bool image = false,
  String date = '2026-09-14',
}) => DriveFile(
  id: id,
  name: name,
  kind: kind,
  size: size,
  createdAt: date,
  modifiedAt: date,
  parentId: null,
  starred: starred,
  shared: shared,
  thumbnailUrl: image ? _image : null,
  uploadStatus: 'available',
);

DriveFolder _folder(
  String id,
  String name,
  int count,
  int size, {
  bool starred = false,
  bool shared = false,
}) => DriveFolder(
  id: id,
  name: name,
  parentId: null,
  createdAt: '2026-09-10',
  modifiedAt: '2026-09-10',
  starred: starred,
  shared: shared,
  recursiveFileCount: count,
  recursiveSize: size,
);

final _files = [
  _file(
    'f1',
    'A weekend in the mountains.jpg',
    FileKind.image,
    2400000,
    starred: true,
    image: true,
  ),
  _file('f2', 'Q3 board update.pdf', FileKind.pdf, 860000, shared: true),
  _file('f3', 'Alpine afternoon.jpg', FileKind.image, 2300000, image: true),
  _file('f4', 'Kayak session.mov', FileKind.video, 48000000),
  _file('f5', 'Lease agreement.docx', FileKind.doc, 120000, starred: true),
  _file('f6', 'Budget 2026.xlsx', FileKind.sheet, 64000),
];
final _folders = [
  _folder('d1', 'Everyday essentials', 12, 40000000),
  _folder('d2', 'Places to remember', 24, 122000000, starred: true),
  _folder('d3', 'Tax documents 2026', 9, 18000000, shared: true),
  _folder('d4', 'Design references', 41, 310000000),
];

class _Auth extends ChangeNotifier implements AuthController {
  @override
  AuthUser? get user =>
      const AuthUser(userId: 1, telegramId: 10, firstName: 'Alex');
  @override
  String? get token => 'fixture';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  _Drive({this.empty = false});
  final bool empty;
  @override
  DriveState state = const DriveState();
  @override
  int get accountGeneration => 0;
  @override
  List<DriveFolder> get folders => empty ? const [] : _folders;
  @override
  DriveFile? file(String id) => _files.where((f) => f.id == id).firstOrNull;
  @override
  DriveFolder? folder(String id) =>
      _folders.where((f) => f.id == id).firstOrNull;
  @override
  DriveFolderViewSnapshot folderViewSnapshot(String? folderId) =>
      DriveFolderViewSnapshot(
        folderId: folderId,
        folder: folderId == null ? null : folder(folderId),
        folders: empty
            ? const []
            : folderId == null
            ? _folders
            : _folders.take(2).toList(),
        files: empty ? const [] : _files,
        path: folderId == null
            ? const []
            : [_folder('root', 'Projects', 3, 0), folder(folderId)!],
        loaded: true,
        loading: false,
        loadingMore: false,
        hasMore: false,
        error: null,
      );
  @override
  DriveRecentsSnapshot recentsSnapshot() =>
      DriveRecentsSnapshot(empty ? const [] : _files.take(4).toList());
  @override
  DriveStarredSnapshot starredSnapshot() => DriveStarredSnapshot(
    files: empty ? const [] : _files.where((f) => f.starred).toList(),
    folders: empty ? const [] : [_folders[1], _folders[3]],
    loaded: true,
    loading: false,
    loadingMore: false,
    hasMore: false,
    error: null,
  );
  @override
  Future<void> ensureStarredLoaded({bool force = false}) async {}
  @override
  Future<void> refresh({bool silent = false, bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Search extends ChangeNotifier implements DriveSearchController {
  @override
  String? get error => null;
  @override
  bool get loading => false;
  @override
  bool get loaded => true;
  @override
  List<DriveFile> get files => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _shares = [
  Share(
    id: 's1',
    token: 'a',
    url: 'https://example.com/s/a',
    permission: SharePermission.preview,
    createdAt: DateTime(2026, 9, 12),
    viewCount: 28,
    downloadCount: 0,
    items: const [],
    primaryName: 'Our mountain weekend',
    primaryKind: ShareItemType.folder,
    itemCount: 12,
  ),
  Share(
    id: 's2',
    token: 'b',
    url: 'https://example.com/s/b',
    permission: SharePermission.download,
    createdAt: DateTime(2026, 9, 2),
    viewCount: 7,
    downloadCount: 3,
    items: const [],
    primaryName: 'Q3 board update.pdf',
    primaryKind: ShareItemType.file,
    itemCount: 1,
  ),
  Share(
    id: 's3',
    token: 'c',
    url: 'https://example.com/s/c',
    permission: SharePermission.download,
    createdAt: DateTime(2026, 8, 2),
    expiresAt: DateTime(2026, 8, 9),
    viewCount: 7,
    downloadCount: 3,
    items: const [],
    primaryName: 'Project handover',
    primaryKind: ShareItemType.folder,
    itemCount: 4,
  ),
  Share(
    id: 's4',
    token: 'd',
    url: 'https://example.com/s/d',
    permission: SharePermission.preview,
    createdAt: DateTime(2026, 7, 2),
    revokedAt: DateTime(2026, 7, 20),
    viewCount: 2,
    downloadCount: 0,
    items: const [],
    primaryName: 'Lease agreement.docx',
    primaryKind: ShareItemType.file,
    itemCount: 1,
  ),
];

class _Shares extends ChangeNotifier implements ShareController {
  _Shares({this.empty = false});
  final bool empty;
  @override
  List<Share> get shares => empty ? const [] : _shares;
  @override
  bool get loading => false;
  @override
  String? get error => null;
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Repo implements DriveRepository {
  _Repo({this.empty = false});
  final bool empty;
  @override
  Future<List<DriveFile>> listArchiveFiles() async =>
      empty ? const [] : _files.skip(2).take(3).toList();
  @override
  Future<List<DriveFile>> listLockedFiles() async =>
      empty ? const [] : _files.take(2).toList();
  @override
  Future<List<DriveFile>> listTrashFiles() async =>
      empty ? const [] : _files.skip(3).toList();
  @override
  Future<List<DriveFolder>> listTrashFolders() async =>
      empty ? const [] : [_folders[2]];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Uploads extends ChangeNotifier implements UploadController {
  @override
  bool get sheetVisible => false;
  @override
  List<UploadItem> get items => const [];
  @override
  UploadItemIdsSnapshot get itemIdsSnapshot =>
      const UploadItemIdsSnapshot([], 0);
  @override
  UploadSummary get summary => const UploadSummary(
    sheetVisible: false,
    itemCount: 0,
    uploadedCount: 0,
    failedCount: 0,
    activeCount: 0,
    waitingForWifi: false,
    uploading: false,
    stillGeneratingThumbs: false,
    progressPermille: 0,
    totalBytes: 0,
    completedBytes: 0,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

int? _tabFor(Widget screen) => switch (screen) {
  DriveScreen() => 0,
  StarredScreen() => 2,
  MySharesScreen() => 3,
  _ => null,
};

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
  double width = 402,
  double height = 874,
  double scale = 1,
  bool highContrast = false,
  bool empty = false,
  bool grid = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  final theme = buildTheme(
    AppBrand.scheme(brightness, highContrast: highContrast),
    highContrast: highContrast,
  ).copyWith(platform: TargetPlatform.iOS);
  debugDefaultTargetPlatformOverride = null;
  final tab = _tabFor(screen);
  for (final width in [320, 640, 960]) {
    final key = await ResizeImage(
      FileImage(File(_image)),
      width: width,
    ).obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: _decoded.clone())),
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => _Auth()),
        driveControllerProvider.overrideWith((_) => _Drive(empty: empty)),
        driveSearchProvider.overrideWith((_) => _Search()),
        shareControllerProvider.overrideWith((_) => _Shares(empty: empty)),
        driveRepositoryProvider.overrideWithValue(_Repo(empty: empty)),
        uploadControllerProvider.overrideWith((_) => _Uploads()),
        viewPreferencesProvider.overrideWith(
          (_) =>
              ViewPreferencesController()
                ..layout = grid ? LayoutMode.grid : LayoutMode.list,
        ),
      ],
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            highContrast: highContrast,
            disableAnimations: true,
            // iPhone 17 safe areas.
            padding: const EdgeInsets.only(top: 62, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 62, bottom: 34),
          ),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child!),
        ),
        home: tab == null
            ? screen
            : Scaffold(
                extendBody: true,
                body: screen,
                bottomNavigationBar: FloatingPillNavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (_) {},
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '');
    final codec = await ui.instantiateImageCodec(
      File(_image).readAsBytesSync(),
    );
    _decoded = (await codec.getNextFrame()).image;
    codec.dispose();
    // Portable stand-ins for San Francisco; device builds use the system font.
    for (final family in [
      'Inter',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF Pro Text',
      '.SF Pro Display',
    ]) {
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

  final pages = <(String, Widget)>[
    ('drive', const DriveScreen()),
    ('folder', const FolderScreen(folderId: 'd1')),
    ('starred', const StarredScreen()),
    ('shared', const MySharesScreen()),
    ('archive', const ArchiveScreen()),
    ('locked', const LockedScreen()),
    ('trash', const TrashScreen()),
  ];

  for (final brightness in Brightness.values) {
    for (final page in pages) {
      testWidgets('${page.$1} composes on the iOS canvas ${brightness.name}', (
        tester,
      ) async {
        await _pump(tester, page.$2, brightness: brightness, height: 1500);
        expect(tester.takeException(), isNull);
        final canvas = brightness == Brightness.dark
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF);
        expect(
          tester
              .widgetList<Scaffold>(find.byType(Scaffold))
              .any(
                (scaffold) =>
                    scaffold.backgroundColor?.toARGB32() == canvas.toARGB32(),
              ),
          isTrue,
        );
        expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
        await capture(tester, 'ios-browse-${page.$1}-${brightness.name}');
      });
      testWidgets('${page.$1} empty state ${brightness.name}', (tester) async {
        await _pump(tester, page.$2, brightness: brightness, empty: true);
        expect(tester.takeException(), isNull);
        if (page.$1 != 'drive') {
          expect(find.byType(IosContentUnavailable), findsOneWidget);
        }
        await capture(tester, 'ios-browse-${page.$1}-empty-${brightness.name}');
      });
    }
  }

  for (final page in pages) {
    testWidgets('${page.$1} fits 320 points at 200% text', (tester) async {
      await _pump(
        tester,
        page.$2,
        width: 320,
        height: 1400,
        scale: 2,
        highContrast: true,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'ios-browse-${page.$1}-accessible');
    });
  }

  for (final page in pages.where(
    (page) => page.$1 == 'drive' || page.$1 == 'starred' || page.$1 == 'shared',
  )) {
    testWidgets('${page.$1} grid layout', (tester) async {
      await _pump(tester, page.$2, grid: true, height: 1500);
      expect(tester.takeException(), isNull);
      await capture(tester, 'ios-browse-${page.$1}-grid');
    });
  }

  testWidgets('overflow controls share one header and one row treatment', (
    tester,
  ) async {
    await _pump(tester, const MySharesScreen(), height: 1500);
    final buttons = tester
        .widgetList<NativeGlassButton>(find.byType(NativeGlassButton))
        .where((button) => button.symbol == 'ellipsis')
        .toList();
    final header = buttons.where((button) => !button.plain).toList();
    final rows = buttons.where((button) => button.plain).toList();
    // The header capsule is Files-sized: 44 points, a light medium glyph.
    expect(header, hasLength(1));
    expect(header.single.size, 44);
    expect(header.single.visualSize, isNull);
    expect(header.single.symbolSize, 17);
    expect(header.single.symbolWeight, 'medium');
    // Shared rows draw the same bare ellipsis as Drive rows, not a pill.
    expect(rows, isNotEmpty);
    expect(rows.every((button) => button.size == 48), isTrue);
  });

  testWidgets('Drive tiles open the three spaces', (tester) async {
    await _pump(tester, const DriveScreen());
    for (final label in ['Archive', 'Locked', 'Trash']) {
      expect(
        find.descendant(
          of: find.byType(IosPressable),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Drive'), findsWidgets);
  });

  testWidgets('Drive search shows an explicit no-results state', (
    tester,
  ) async {
    final container = await _pump(tester, const DriveScreen());
    container.read(searchQueryProvider(SearchScope.drive))
      ..update('zzz')
      ..submit();
    await tester.pumpAndSettle();
    expect(find.text('No Results'), findsOneWidget);
    // Spaces and recents step aside while a query is shown.
    expect(find.text('Recents'), findsNothing);
    await capture(tester, 'ios-browse-drive-no-results');
  });

  testWidgets('Shared groups live links before ended ones', (tester) async {
    await _pump(tester, const MySharesScreen(), height: 1200);
    final active = tester.getTopLeft(find.text('Active')).dy;
    final ended = tester.getTopLeft(find.text('Expired or Revoked')).dy;
    expect(active, lessThan(ended));
    expect(
      tester.getTopLeft(find.text('Our mountain weekend')).dy,
      lessThan(ended),
    );
    expect(
      tester.getTopLeft(find.text('Project handover')).dy,
      greaterThan(ended),
    );
    expect(find.text('Active link'), findsNWidgets(2));
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Revoked'), findsOneWidget);
  });

  testWidgets('large title collapses into the bar on scroll', (tester) async {
    await _pump(tester, const StarredScreen(), height: 560);
    final before = tester.getTopLeft(find.text('Folders')).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Folders')).dy, lessThan(before));
    expect(tester.takeException(), isNull);
    await capture(tester, 'ios-browse-starred-scrolled');
  });
}
