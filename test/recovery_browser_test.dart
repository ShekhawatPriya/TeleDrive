import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/core/navigation/recovery_page.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/drive/drive_tab_commands.dart';
import 'package:flutter_m_fsdk/features/drive/starred_screen.dart';
import 'package:flutter_m_fsdk/features/profile/archive_screen.dart';
import 'package:flutter_m_fsdk/features/profile/locked_screen.dart';
import 'package:flutter_m_fsdk/features/profile/trash_screen.dart';
import 'package:flutter_m_fsdk/features/profile/components/recovery_browser.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/ios_more_menu.dart';
import 'package:flutter_m_fsdk/widgets/media_thumb.dart';
import 'package:flutter_m_fsdk/features/share/my_shares_screen.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/models/share_models.dart';
import 'package:flutter_m_fsdk/features/drive/view_preferences_controller.dart';
import 'package:flutter_m_fsdk/widgets/native_item_context_menu.dart';
import 'package:flutter_m_fsdk/widgets/native_selection_actions.dart';
import 'platform_folder_ui_test.dart' show capture;

final _photoPath = File('test/fixtures/design/alpine.jpg').absolute.path;
final _photo = DriveFile(
  id: 'photo',
  name: 'Mountain morning.jpg',
  kind: FileKind.image,
  size: 1200000,
  createdAt: '2026-09-17',
  modifiedAt: '2026-09-17',
  parentId: null,
  starred: true,
  thumbnailUrl: _photoPath,
  uploadStatus: 'available',
);
final _document = DriveFile(
  id: 'doc',
  name: 'Travel notes.pdf',
  kind: FileKind.pdf,
  size: 42000,
  createdAt: '2026-09-17',
  modifiedAt: '2026-09-17',
  parentId: null,
  starred: false,
);
const _folder = DriveFolder(
  id: 'folder',
  name: 'Trip photographs',
  parentId: null,
  createdAt: '',
  modifiedAt: '',
  starred: true,
  recursiveFileCount: 8,
  recursiveSize: 12000000,
);

class _Auth extends ChangeNotifier implements AuthController {
  @override
  AuthUser? user = const AuthUser(
    userId: 1,
    telegramId: 10,
    firstName: 'Fixture',
  );
  @override
  String? get token => 'fixture';
  void switchUser() {
    user = const AuthUser(userId: 2, telegramId: 20, firstName: 'Second');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Repo implements DriveRepository {
  List<DriveFile> files = [_photo, _document];
  List<DriveFolder> folders = [_folder];
  Completer<List<DriveFile>>? pending;
  @override
  Future<List<DriveFile>> listArchiveFiles() async =>
      pending == null ? files : pending!.future;
  @override
  Future<List<DriveFile>> listLockedFiles() async =>
      pending == null ? files : pending!.future;
  @override
  Future<List<DriveFile>> listTrashFiles() async =>
      pending == null ? files : pending!.future;
  @override
  Future<List<DriveFolder>> listTrashFolders() async => folders;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState state = const DriveState();
  @override
  DriveFile? file(String id) => id == _photo.id ? _photo : _document;
  @override
  DriveFolder? folder(String id) => _folder;
  @override
  DriveStarredSnapshot starredSnapshot() => DriveStarredSnapshot(
    files: [_photo, _document],
    folders: [_folder],
    loaded: true,
    loading: false,
    loadingMore: false,
    hasMore: false,
    error: null,
  );
  @override
  Future<void> ensureStarredLoaded({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _share = Share(
  id: 'share',
  token: 'fixture',
  url: 'https://example.com/s/fixture',
  permission: SharePermission.download,
  createdAt: DateTime(2026, 9, 17),
  viewCount: 12,
  downloadCount: 3,
  items: const [],
  primaryName: 'Trip photographs',
  primaryKind: ShareItemType.folder,
  itemCount: 8,
);

class _Shares extends ChangeNotifier implements ShareController {
  @override
  List<Share> shares = [_share];
  @override
  bool get loading => false;
  @override
  String? get error => null;
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  TargetPlatform platform = TargetPlatform.iOS,
  Brightness brightness = Brightness.light,
  double scale = 1,
  _Repo? repo,
  _Auth? auth,
  _Shares? shares,
  bool grid = false,
  bool disableAnimations = true,
}) async {
  tester.view.physicalSize = Size(scale == 2 ? 320 : 390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(
    AppBrand.scheme(brightness, highContrast: scale == 2),
  ).copyWith(platform: platform);
  debugDefaultTargetPlatformOverride = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driveRepositoryProvider.overrideWithValue(repo ?? _Repo()),
        shareControllerProvider.overrideWith((_) => shares ?? _Shares()),
        viewPreferencesProvider.overrideWith(
          (_) =>
              ViewPreferencesController()
                ..layout = grid ? LayoutMode.grid : LayoutMode.list,
        ),
        driveControllerProvider.overrideWith((_) => _Drive()),
        authControllerProvider.overrideWith((_) => auth ?? _Auth()),
      ],
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            highContrast: scale == 2,
            disableAnimations: disableAnimations,
          ),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child!),
        ),
        home: screen,
      ),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    await precacheImage(
      ResizeImage(FileImage(File(_photoPath)), width: 320),
      context,
    );
  });
  if (repo?.pending != null)
    await tester.pump();
  else
    await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '');
    for (final family in [
      'Inter',
      'Roboto',
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
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        for (final page in <(String, Widget)>[
          ('archive', const ArchiveScreen()),
          ('locked', const LockedScreen()),
          ('trash', const TrashScreen()),
        ]) {
          testWidgets(
            'recovery ${page.$1} ${platform.name} ${brightness.name} $scale',
            (tester) async {
              await _pump(
                tester,
                page.$2,
                platform: platform,
                brightness: brightness,
                scale: scale,
              );
              expect(find.byType(MediaThumb), findsWidgets);
              expect(tester.takeException(), isNull);
              await capture(
                tester,
                'recovery-${page.$1}-${platform.name}-${brightness.name}-$scale',
              );
              if (platform == TargetPlatform.iOS) {
                expect(find.byType(NativeItemContextMenu), findsWidgets);
                final options = find.byWidgetPredicate(
                  (widget) =>
                      widget is IosMoreButton &&
                      widget.tooltip.endsWith(' options'),
                );
                final menu = tester.widget<IosMoreButton>(options);
                final context = tester.element(options);
                menu
                    .sectionsBuilder(context)
                    .expand((s) => s.items)
                    .firstWhere((item) => item.label == 'Select')
                    .onTap();
                await tester.pumpAndSettle();
                final actions = tester.widget<NativeSelectionActions>(
                  find.byType(NativeSelectionActions),
                );
                expect(actions.enabled, isFalse);
                actions.onSelectAll!();
                await tester.pumpAndSettle();
                expect(
                  tester
                      .widget<NativeSelectionActions>(
                        find.byType(NativeSelectionActions),
                      )
                      .enabled,
                  isTrue,
                );
                await capture(
                  tester,
                  'recovery-select-${page.$1}-${brightness.name}-$scale',
                );
                expect(tester.takeException(), isNull);
              }
            },
          );
        }
      }
    }
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      for (final grid in [false, true]) {
        testWidgets('shared native rows ${brightness.name} $scale grid=$grid', (
          tester,
        ) async {
          await _pump(
            tester,
            const MySharesScreen(),
            brightness: brightness,
            scale: scale,
            grid: grid,
          );
          expect(find.byType(NativeItemContextMenu), findsOneWidget);
          expect(find.textContaining('12 views'), findsOneWidget);
          expect(find.textContaining('3 downloads'), findsOneWidget);
          expect(find.text('Active link'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'shared-native-${brightness.name}-$scale-$grid',
          );
        });
      }
    }
  }
  testWidgets(
    'shared link hold actions resolve fresh status and reject old account',
    (tester) async {
      final auth = _Auth();
      final shares = _Shares();
      await _pump(tester, const MySharesScreen(), auth: auth, shares: shares);
      final menu = tester.widget<NativeItemContextMenu>(
        find.byType(NativeItemContextMenu),
      );
      final oldActions = menu.sectionsBuilder().expand((s) => s.items).toList();
      expect(oldActions.map((item) => item.label), [
        'Open',
        'Copy link',
        'Share link',
        'Revoke link',
      ]);
      expect(
        oldActions
            .firstWhere((item) => item.label == 'Revoke link')
            .leadingIcon,
        Icons.link_off_outlined,
      );
      shares.shares = [
        Share(
          id: _share.id,
          token: _share.token,
          url: _share.url,
          permission: _share.permission,
          createdAt: _share.createdAt,
          revokedAt: DateTime(2026, 9, 18),
          viewCount: 12,
          downloadCount: 3,
          items: const [],
          primaryName: _share.primaryName,
          primaryKind: _share.primaryKind,
          itemCount: 8,
        ),
      ];
      expect(
        menu.sectionsBuilder().expand((s) => s.items).map((i) => i.label),
        ['Open'],
      );
      auth.switchUser();
      await tester.pump();
      expect(menu.sectionsBuilder(), isEmpty);
      oldActions.firstWhere((i) => i.label == 'Revoke link').onTap();
      await tester.pumpAndSettle();
      expect(find.text('Revoke share?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final page in [
    (
      'archive',
      const ArchiveScreen(),
      'These items are hidden from the main drive until you unarchive them.',
      '2 items',
    ),
    (
      'locked',
      const LockedScreen(),
      'These items are hidden from the main drive until you unlock them.',
      '2 items',
    ),
    (
      'trash',
      const TrashScreen(),
      'Restore items to their original location, or delete them forever. Items stay in Telegram until permanently deleted.',
      '3 items',
    ),
  ]) {
    testWidgets('${page.$1} reveals the initial body together', (tester) async {
      final repo = _Repo()..pending = Completer<List<DriveFile>>();
      await _pump(tester, page.$2, repo: repo);
      expect(find.text(page.$3), findsNothing);
      expect(find.text(page.$4), findsNothing);
      expect(find.text(_photo.name), findsNothing);
      expect(find.text(_document.name), findsNothing);
      repo.pending!.complete([_photo, _document]);
      await tester.pump();
      await tester.pump();
      expect(find.text(page.$3), findsOneWidget);
      expect(find.text(page.$4), findsOneWidget);
      expect(find.text(_photo.name), findsOneWidget);
      expect(find.text(_document.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final screen in [
    const ArchiveScreen(),
    const LockedScreen(),
    const TrashScreen(),
  ]) {
    for (final populated in [false, true]) {
      testWidgets(
        '${screen.runtimeType} enters without sweeping text across the viewport populated=$populated',
        (tester) async {
          var open = false;
          await _pump(
            tester,
            StatefulBuilder(
              builder: (context, setState) => Navigator(
                pages: [
                  MaterialPage<void>(
                    key: const ValueKey('drive'),
                    child: Scaffold(
                      body: TextButton(
                        onPressed: () => setState(() => open = true),
                        child: const Text('Open recovery'),
                      ),
                    ),
                  ),
                  if (open)
                    recoveryPage(
                      context: context,
                      key: const ValueKey('recovery'),
                      child: screen,
                    ),
                ],
                onDidRemovePage: (_) => setState(() => open = false),
              ),
            ),
            disableAnimations: false,
            repo: _Repo()
              ..files = populated ? [_photo, _document] : []
              ..folders = populated ? [_folder] : [],
          );
          await tester.tap(find.text('Open recovery'));
          await tester.pump();
          for (final milliseconds in [0, 16, 64, 120, 300]) {
            await tester.pump(Duration(milliseconds: milliseconds));
            expect(tester.getTopLeft(find.byType(RecoveryBrowser)).dx, 0);
            expect(tester.getSize(find.byType(RecoveryBrowser)).width, 390);
          }
          await capture(
            tester,
            'recovery-entry-${screen.runtimeType}-$populated',
          );
          await tester.pumpAndSettle();

          // Cancelled and completed edge-back gestures must retain Cupertino's
          // interactive motion even though tapping a space presents immediately.
          final route =
              ModalRoute.of(tester.element(find.byType(RecoveryBrowser)))!
                  as PageRoute;
          expect(route.popGestureEnabled, isTrue);
          final partial = await tester.startGesture(const Offset(1, 300));
          await partial.moveBy(const Offset(20, 0));
          await tester.pump();
          await partial.moveBy(const Offset(80, 0));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.getTopLeft(find.byType(RecoveryBrowser)).dx,
            greaterThan(0),
          );
          await partial.moveBy(const Offset(-60, 0));
          await tester.pump(const Duration(milliseconds: 200));
          await partial.up();
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(find.byType(RecoveryBrowser)).dx, 0);
          await tester.dragFrom(const Offset(1, 300), const Offset(320, 0));
          await tester.pumpAndSettle();
          expect(find.byType(RecoveryBrowser), findsNothing);
          expect(find.text('Open recovery'), findsOneWidget);

          await tester.tap(find.text('Open recovery'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.byType(RecoveryBrowser), findsNothing);
        },
      );
    }
  }
  testWidgets('holding recovery item offers actions before selecting', (
    tester,
  ) async {
    await _pump(tester, const ArchiveScreen());
    final hold = await tester.startGesture(
      tester.getCenter(find.text(_photo.name)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('Unarchive'), findsOneWidget);
    expect(find.text('Move to Trash'), findsOneWidget);
    expect(find.byType(NativeSelectionActions), findsNothing);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NativeSelectionActions>(find.byType(NativeSelectionActions))
          .enabled,
      isTrue,
    );
  });
  testWidgets('failed recovery load offers retry without claiming zero items', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      RecoveryBrowser(
        title: 'Archive',
        description: 'Archived files',
        emptyBody: 'No files',
        files: const [],
        loading: false,
        error: 'Could not load Archive.',
        selectMode: false,
        selectedFiles: const {},
        selectedFolders: const {},
        onRefresh: () async {
          retries++;
        },
        onSelect: () {},
        onDone: () {},
        onSelectAll: () {},
        onClear: () {},
        actions: const [],
        fileMenu: (_) => [],
        folderMenu: (_) => [],
        onFileSelect: (_) {},
        onFolderSelect: (_) {},
      ),
    );
    expect(find.text('0 items'), findsNothing);
    expect(find.text('Could not load Archive.'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late shelf response cannot show previous account files', (
    tester,
  ) async {
    final repo = _Repo()..pending = Completer<List<DriveFile>>();
    final old = repo.pending!;
    final auth = _Auth();
    await _pump(tester, const ArchiveScreen(), repo: repo, auth: auth);
    repo.pending = null;
    repo.files = [];
    auth.switchUser();
    await tester.pumpAndSettle();
    old.complete([_photo]);
    await tester.pumpAndSettle();
    expect(find.text(_photo.name), findsNothing);
    expect(find.text('0 items'), findsOneWidget);
  });
  testWidgets('Starred file and folder holds share Drive selection contract', (
    tester,
  ) async {
    await _pump(tester, const StarredScreen());
    expect(find.byType(NativeItemContextMenu), findsNWidgets(3));
    final menus = tester.widgetList<NativeItemContextMenu>(
      find.byType(NativeItemContextMenu),
    );
    for (final menu in menus) {
      expect(
        menu.sectionsBuilder().expand((s) => s.items).map((i) => i.label),
        contains('Select'),
      );
    }
    menus.first
        .sectionsBuilder()
        .expand((s) => s.items)
        .firstWhere((i) => i.label == 'Select')
        .onTap();
    await tester.pumpAndSettle();
    expect(find.byType(NativeSelectionActions), findsOneWidget);
    final context = tester.element(find.byType(StarredScreen));
    expect(
      ProviderScope.containerOf(
        context,
      ).read(selectionModeStateProvider).isSelectModeForTab(2),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
