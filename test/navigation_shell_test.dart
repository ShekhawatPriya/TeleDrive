import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m_fsdk/main_shell.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_sheet.dart';
import 'package:flutter_m_fsdk/features/upload/ui/components/upload_collapsed_bar.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/profile/gallery_backup_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';

class _Auth extends ChangeNotifier implements AuthController {
  @override
  bool get isAuthenticated => false;
  @override
  AuthUser? get user => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState state = const DriveState();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Shares extends ChangeNotifier implements ShareController {
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Backup extends ChangeNotifier implements GalleryBackupController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Uploads extends ChangeNotifier implements UploadController {
  _Uploads({this.active = false});
  final bool active;
  @override
  bool get sheetVisible => active;
  @override
  List<UploadItem> get items => active
      ? [
          UploadItem(
            localId: 'one',
            uploadClientId: 'one',
            name: 'one.pdf',
            size: 100,
            mimeType: 'application/pdf',
            path: '',
            status: UploadStatus.waitingForWifi,
          ),
        ]
      : [];
  @override
  UploadItemIdsSnapshot get itemIdsSnapshot =>
      UploadItemIdsSnapshot(items.map((i) => i.localId).toList(), 0);

  @override
  UploadSummary get summary => UploadSummary(
    sheetVisible: active,
    itemCount: active ? 1 : 0,
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

Widget _scope(Widget child, {bool uploading = false}) => ProviderScope(
  overrides: [
    shareControllerProvider.overrideWith((_) => _Shares()),
    authControllerProvider.overrideWith((_) => _Auth()),
    driveControllerProvider.overrideWith((_) => _Drive()),
    galleryBackupControllerProvider.overrideWith((_) => _Backup()),
    uploadControllerProvider.overrideWith((_) => _Uploads(active: uploading)),
  ],
  child: child,
);
GoRouter _router() => GoRouter(
  initialLocation: '/drive',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        for (final path in ['drive', 'photos', 'starred', 'shared'])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/$path',
                builder: (_, _) => _Editor(label: path),
              ),
            ],
          ),
      ],
    ),
    GoRoute(
      path: '/shared/:id',
      builder: (_, _) => const Scaffold(body: Text('Share details')),
    ),
  ],
);

class _Editor extends StatefulWidget {
  const _Editor({required this.label});
  final String label;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(key: ValueKey('edit-${widget.label}'), controller: controller);
}

void main() {
  testWidgets('router owns tabs, restores state and opens detail routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_scope(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(FloatingActionButton)).bottom,
      lessThan(tester.getRect(find.byType(FloatingPillNavigationBar)).top),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-drive')),
      'preserved',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingPillNavigationBar),
        matching: find.text('Shared'),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/shared');
    router.push('/shared/42');
    await tester.pumpAndSettle();
    expect(find.text('Share details'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-shared')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingPillNavigationBar),
        matching: find.text('Drive'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('preserved'), findsOneWidget);
  });
  testWidgets('floating upload control follows keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_scope(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'expanded uploads preserve actual shell tabs on ${platform.name}',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = _router();
        addTearDown(router.dispose);
        await tester.pumpWidget(
          _scope(
            MaterialApp.router(
              theme: ThemeData(platform: platform),
              routerConfig: router,
            ),
            uploading: true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(UploadCollapsedBar));
        await tester.pumpAndSettle();
        final panel = find.byKey(const ValueKey('upload-panel-surface'));
        final nav = find.byType(FloatingPillNavigationBar);
        expect(
          tester.getRect(panel).bottom,
          closeTo(
            platform == TargetPlatform.iOS
                ? tester.getRect(nav).bottom
                : tester.getRect(nav).top,
            1,
          ),
        );
        await tester.drag(find.text('Uploads'), const Offset(0, -450));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Photos')),
        );
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/photos');
        expect(find.byType(UploadSheet), findsOneWidget);
        expect(
          tester.getRect(panel).bottom,
          closeTo(
            platform == TargetPlatform.iOS
                ? tester.getRect(nav).bottom
                : tester.getRect(nav).top,
            1,
          ),
        );
        await tester.drag(find.text('Uploads'), const Offset(0, 1000));
        await tester.pumpAndSettle();
        expect(find.byType(UploadSheet), findsNothing);
        expect(find.byType(UploadCollapsedBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('expanded shell uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_scope(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(FloatingPillNavigationBar), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Photos'),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/photos');
    expect(tester.takeException(), isNull);
  });
}
