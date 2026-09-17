import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_item_context_menu.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_selection_bar.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/native_glass_button.dart';
import 'package:flutter_m_fsdk/widgets/file_list_tile.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_top_bar.dart';
import 'package:flutter_m_fsdk/widgets/native_item_context_menu.dart';

const fixtureFile = DriveFile(
  id: 'one',
  name: 'Travel notes.pdf',
  kind: FileKind.pdf,
  size: 100,
  modifiedAt: '2026-09-17',
  createdAt: '',
  parentId: null,
  starred: false,
);

class _Auth extends ChangeNotifier implements AuthController {
  @override
  AuthUser? user = const AuthUser(
    userId: 1,
    telegramId: 10,
    firstName: 'Fixture',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  DriveFile current = fixtureFile;
  int stars = 0;
  @override
  DriveFile? file(String id) => current;
  @override
  Future<void> toggleStar(String id, {bool folder = false}) async {
    stars++;
    current = current.copyWith(starred: !current.starred);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  _Auth? auth,
  _Drive? drive,
}) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(AppBrand.scheme(brightness));
  debugDefaultTargetPlatformOverride = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => auth ?? _Auth()),
        driveControllerProvider.overrideWith((_) => drive ?? _Drive()),
      ],
      child: MaterialApp(
        theme: theme.copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child!),
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/modernization/$name.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    for (final family in [
      '.SF Pro Text',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      'Roboto',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    }
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'iOS selection header and bottom actions ${brightness.name} $scale',
        (tester) async {
          final calls = <String>[];
          Widget bar(bool actions) => DriveSelectionBar(
            selectedCount: 3,
            actionsOnly: actions,
            onCancel: () => calls.add('Done'),
            onShare: () => calls.add('Share'),
            onStar: () => calls.add('Star'),
            onMove: () => calls.add('Move'),
            onDelete: () => calls.add('Delete'),
          );
          await _pump(
            tester,
            Column(
              children: [
                bar(false),
                Expanded(
                  child: ListView(
                    children: [
                      for (final name in [
                        'Travel notes.pdf',
                        'September plans.pdf',
                        'Project brief.pdf',
                      ])
                        FileListTile(
                          name: name,
                          subtitle: 'PDF · 2.4 MB',
                          file: fixtureFile,
                          selected: true,
                          onTap: () {},
                        ),
                    ],
                  ),
                ),
                bar(true),
              ],
            ),
            brightness: brightness,
            scale: scale,
          );
          expect(find.byType(TextButton), findsNothing);
          expect(tester.getRect(find.text('3 selected')).top, lessThan(100));
          for (final label in ['Share', 'Star', 'Move', 'Delete']) {
            final target = find.byTooltip(label);
            expect(tester.getRect(target).top, greaterThan(600));
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
            await tester.tap(target);
          }
          await tester.tap(find.text('Done'));
          expect(calls, ['Share', 'Star', 'Move', 'Delete', 'Done']);
          await preview(tester, 'ios-selection-${brightness.name}-$scale');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('iOS photo actions expose Share, Star, Info and Delete', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      Column(
        children: [
          const Spacer(),
          PhotoViewerActions(
            file: fixtureFile,
            onDownload: () => calls.add('Download'),
            onShare: () => calls.add('Share'),
            onStar: () => calls.add('Star'),
            onInfo: () => calls.add('Info'),
            onDelete: () => calls.add('Delete'),
          ),
        ],
      ),
      scale: 2,
    );
    for (final label in ['Share', 'Add star', 'Info', 'Delete']) {
      await tester.tap(find.byTooltip(label));
    }
    expect(find.byTooltip('Download'), findsNothing);
    expect(calls, ['Share', 'Star', 'Info', 'Delete']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero selection disables every batch action', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      DriveSelectionBar(
        selectedCount: 0,
        actionsOnly: true,
        onCancel: () {},
        onShare: () => calls++,
        onStar: () => calls++,
        onMove: () => calls++,
        onDelete: () => calls++,
      ),
    );
    for (final widget in tester.widgetList<NativeGlassButton>(
      find.byType(NativeGlassButton),
    )) {
      expect(widget.onPressed, isNull);
    }
    await tester.tap(find.byTooltip('Delete'));
    expect(calls, 0);
  });
  testWidgets(
    'context fallback opens actions, refreshes state and rejects account changes',
    (tester) async {
      final auth = _Auth();
      final drive = _Drive();
      var opened = 0;
      await _pump(
        tester,
        Center(
          child: DriveItemContextMenu(
            file: fixtureFile,
            onOpen: () => opened++,
            onSelect: () {},
            child: const SizedBox(
              width: 240,
              height: 100,
              child: ColoredBox(color: Colors.blue, child: Text('Hold file')),
            ),
          ),
        ),
        auth: auth,
        drive: drive,
      );
      final hold = await tester.startGesture(
        tester.getCenter(find.text('Hold file')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await hold.up();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoContextMenuAction), findsWidgets);
      expect(opened, 0);
      await tester.tap(find.text('Star'));
      await tester.pumpAndSettle();
      expect(drive.stars, 1);
      final holdAgain = await tester.startGesture(
        tester.getCenter(find.text('Hold file')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await holdAgain.up();
      await tester.pumpAndSettle();
      expect(find.text('Unstar'), findsOneWidget);
      auth.user = const AuthUser(userId: 2, telegramId: 20, firstName: 'Other');
      auth.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Unstar'));
      await tester.pumpAndSettle();
      expect(drive.stars, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Android keeps the supplied tile gestures', (tester) async {
    await _pump(
      tester,
      DriveItemContextMenu(
        file: fixtureFile,
        onOpen: () {},
        onSelect: () {},
        child: const Text('Android tile'),
      ),
      platform: TargetPlatform.android,
    );
    expect(find.byType(NativeItemContextMenu), findsNothing);
    expect(find.byType(CupertinoContextMenu), findsNothing);
    expect(find.text('Android tile'), findsOneWidget);
  });
}
