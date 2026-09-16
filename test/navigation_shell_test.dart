import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m_fsdk/main_shell.dart';
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

Widget _scope(Widget child) => ProviderScope(
  overrides: [
    shareControllerProvider.overrideWith((_) => _Shares()),
    authControllerProvider.overrideWith((_) => _Auth()),
    driveControllerProvider.overrideWith((_) => _Drive()),
    galleryBackupControllerProvider.overrideWith((_) => _Backup()),
    uploadControllerProvider.overrideWith((_) => _Uploads()),
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
