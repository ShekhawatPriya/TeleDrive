import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/features/upload/ui/components/bottom_action_system.dart';
import 'package:flutter_m_fsdk/features/upload/ui/components/upload_card.dart';
import 'package:flutter_m_fsdk/features/upload/ui/components/upload_collapsed_bar.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_sheet.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_status_label.dart';
import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';

final _photo = File('test/fixtures/design/alpine.jpg').absolute.path;

UploadItem _item(
  int id,
  UploadStatus status, {
  bool photo = false,
  bool ready = true,
}) => UploadItem(
  localId: '$id',
  uploadClientId: 'upload-$id',
  name: [
    'Alpine afternoon.jpg',
    'IMG_6789.HEIC',
    'IMG_6791.HEIC',
    'September presentation.pdf',
    'Weekend in the mountains.jpg',
    'Project notes and references for September.txt',
  ][id % 6],
  size: (id + 1) * 1024 * 1024,
  mimeType: photo ? 'image/jpeg' : 'application/octet-stream',
  path: photo ? _photo : '',
  status: status,
  serverProgress: .42,
  thumbnailReady: ready,
  thumbnailUrl: photo && ready ? _photo : null,
  error: status == UploadStatus.failed
      ? 'Connection interrupted. Try again when you’re connected.'
      : null,
);

class _Uploads extends ChangeNotifier implements UploadController {
  _Uploads(this.items);
  @override
  List<UploadItem> items;
  final cancelled = <String>[];
  final removed = <String>[];
  int retries = 0;
  int mobileData = 0;
  @override
  bool get sheetVisible => items.isNotEmpty;
  @override
  UploadItemIdsSnapshot get itemIdsSnapshot =>
      UploadItemIdsSnapshot(items.map((i) => i.localId).toList(), items.length);
  @override
  UploadSummary get summary => UploadSummary(
    sheetVisible: sheetVisible,
    itemCount: items.length,
    uploadedCount: items.where((i) => i.status == UploadStatus.uploaded).length,
    failedCount: items
        .where(
          (i) =>
              i.status == UploadStatus.failed ||
              i.status == UploadStatus.cancelled,
        )
        .length,
    activeCount: items.where((i) => !uploadIsTerminal(i.status)).length,
    waitingForWifi: items.any((i) => i.status == UploadStatus.waitingForWifi),
    uploading: items.any((i) => !uploadIsTerminal(i.status)),
    stillGeneratingThumbs:
        items.isNotEmpty &&
        items.every((i) => i.status == UploadStatus.uploaded) &&
        items.any((i) => !i.thumbnailReady),
    progressPermille: items.isEmpty
        ? 0
        : (items.fold<double>(0, (sum, i) => sum + i.progress) /
                  items.length *
                  1000)
              .round(),
    totalBytes: items.fold<int>(0, (sum, i) => sum + i.size),
    completedBytes: items.fold<int>(
      0,
      (sum, i) => sum + (i.size * i.progress).round(),
    ),
  );
  @override
  Future<void> cancelItem(String id) async {
    cancelled.add(id);
  }

  @override
  void removeFailed(String id) {
    removed.add(id);
  }

  @override
  Future<void> confirmUpload() async {
    retries++;
  }

  @override
  Future<void> enableMobileDataUploads() async {
    mobileData++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState state = const DriveState();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(
  WidgetTester tester,
  _Uploads uploads, {
  TargetPlatform platform = TargetPlatform.iOS,
  Brightness brightness = Brightness.dark,
  double width = 402,
  double height = 874,
  bool navigation = true,
  double scale = 1,
  bool contrast = false,
  Widget? body,
  bool deleting = false,
  ValueChanged<int>? onTabSelected,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.resetViewPadding);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(AppBrand.scheme(brightness, highContrast: contrast));
  debugDefaultTargetPlatformOverride = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        uploadControllerProvider.overrideWith((_) => uploads),
        driveControllerProvider.overrideWith(
          (_) => _Drive()
            ..state = DriveState(
              deleteProgress: deleting
                  ? (completed: 1, failed: 0, total: 3)
                  : null,
            ),
        ),
      ],
      child: MaterialApp(
        theme: theme.copyWith(
          platform: platform,
          textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            highContrast: contrast,
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 24, bottom: 34),
          ),
          child: RepaintBoundary(
            key: const ValueKey('upload-preview'),
            child: child,
          ),
        ),
        home: Scaffold(
          extendBody: true,
          appBar: AppBar(title: const Text('Your drive')),
          body:
              body ??
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text('Files', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    for (final item in uploads.items.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text('In your drive'),
                      ),
                  ],
                ),
              ),
          floatingActionButton: body == null
              ? const BottomActionSystem(showFab: true)
              : null,
          bottomNavigationBar: body == null && navigation
              ? FloatingPillNavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: onTabSelected ?? (_) {},
                )
              : null,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await precacheImage(
      ResizeImage(FileImage(File(_photo)), width: 160, height: 160),
      tester.element(find.byType(Scaffold).first),
    );
  });
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(UploadCollapsedBar));
  await tester.pumpAndSettle();
}

Future<void> _preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('upload-preview')),
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

void main() {
  setUpAll(() async {
    for (final family in [
      'Inter',
      'Roboto',
      '.SF Pro Text',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
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
      testWidgets('upload layouts ${platform.name} ${brightness.name}', (
        tester,
      ) async {
        final uploads = _Uploads([
          _item(0, UploadStatus.uploaded, photo: true),
          _item(1, UploadStatus.uploaded),
          _item(2, UploadStatus.uploadingOriginalToTelegram),
          _item(3, UploadStatus.preparingMetadata),
          _item(4, UploadStatus.queued, photo: true),
          _item(5, UploadStatus.queued),
        ]);
        await _pump(
          tester,
          uploads,
          platform: platform,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        await _preview(
          tester,
          'upload-collapsed-${platform.name}-${brightness.name}',
        );
        await _open(tester);
        expect(find.byType(UploadSheet), findsOneWidget);
        expect(find.text('2 of 6 uploaded'), findsWidgets);
        expect(tester.takeException(), isNull);
        await _preview(
          tester,
          'upload-sheet-${platform.name}-${brightness.name}',
        );
        // Dragging the header expands the same scrollable sheet.
        final sheet = tester.widget<DraggableScrollableSheet>(
          find.byType(DraggableScrollableSheet),
        );
        final initial = tester
            .getSize(find.byType(CustomScrollView).last)
            .height;
        await tester.drag(find.text('Uploads'), const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(CustomScrollView).last).height,
          greaterThan(initial),
        );
        expect(sheet.maxChildSize, .92);
        await _preview(
          tester,
          'upload-expanded-${platform.name}-${brightness.name}',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('upload accessibility ${platform.name} ${brightness.name}', (
        tester,
      ) async {
        final uploads = _Uploads([
          _item(0, UploadStatus.failed),
          _item(1, UploadStatus.cancelled),
          _item(2, UploadStatus.waitingForWifi),
        ]);
        await _pump(
          tester,
          uploads,
          platform: platform,
          brightness: brightness,
          width: 320,
          scale: 2,
          contrast: true,
        );
        expect(tester.takeException(), isNull);
        await _preview(
          tester,
          'upload-accessible-collapsed-${platform.name}-${brightness.name}',
        );
        await _open(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use mobile data'));
        expect(uploads.mobileData, 1);
        await _preview(
          tester,
          'upload-accessible-sheet-${platform.name}-${brightness.name}',
        );
        for (
          var attempt = 0;
          attempt < 8 &&
              find.text('Retry uploads').hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(find.byType(UploadSheet), const Offset(0, -240));
          await tester.pumpAndSettle();
        }
        expect(find.text('Retry uploads').hitTestable(), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retry uploads'));
        expect(uploads.retries, 1);
        await _preview(
          tester,
          'upload-accessible-actions-${platform.name}-${brightness.name}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final count in [1, 2]) {
    for (final brightness in Brightness.values) {
      for (final waiting in [false, true]) {
        testWidgets(
          'compact $count uploads ${brightness.name} waiting=$waiting',
          (tester) async {
            var selectedTab = 0;
            final uploads = _Uploads([
              for (var i = 0; i < count; i++)
                _item(
                  i,
                  waiting
                      ? UploadStatus.waitingForWifi
                      : UploadStatus.uploadingOriginalToTelegram,
                ),
            ]);
            await _pump(
              tester,
              uploads,
              brightness: brightness,
              onTabSelected: (index) => selectedTab = index,
            );
            await _open(tester);
            final surface = find.byKey(const ValueKey('upload-panel-surface'));
            final nav = find.byType(FloatingPillNavigationBar);
            expect(
              tester.getRect(surface).bottom,
              closeTo(tester.getRect(nav).top, 1),
            );
            final lastRow = find.byType(UploadCard).last;
            expect(
              tester.getRect(surface).bottom - tester.getRect(lastRow).bottom,
              closeTo(16, 1),
            );
            expect(find.byType(UploadCollapsedBar), findsNothing);
            if (waiting) {
              final button = tester.widget<CupertinoButton>(
                find.ancestor(
                  of: find.text('Use mobile data'),
                  matching: find.byType(CupertinoButton),
                ),
              );
              expect(button.color, isNull);
              await tester.pumpAndSettle();
              await tester.tap(find.text('Use mobile data'));
              expect(uploads.mobileData, 1);
            }
            await _preview(
              tester,
              'upload-compact-$count-${brightness.name}-${waiting ? 'wifi' : 'active'}',
            );
            await tester.drag(find.text('Uploads'), const Offset(0, -450));
            await tester.pumpAndSettle();
            expect(
              tester.getRect(surface).bottom,
              closeTo(tester.getRect(nav).top, 1),
            );
            await tester.tap(
              find.descendant(of: nav, matching: find.text('Photos')),
            );
            await tester.pumpAndSettle();
            expect(selectedTab, 1);
            expect(find.byType(UploadSheet), findsOneWidget);
            // Back minimizes details without cancelling the queue.
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(find.byType(UploadSheet), findsNothing);
            expect(uploads.items, hasLength(count));
            expect(find.byType(UploadCollapsedBar), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'small queue remains reachable at 320 points and 200% on ${platform.name}',
      (tester) async {
        final uploads = _Uploads([
          _item(0, UploadStatus.failed),
          _item(1, UploadStatus.waitingForWifi),
        ]);
        await _pump(
          tester,
          uploads,
          platform: platform,
          width: 320,
          height: 640,
          scale: 2,
          contrast: true,
        );
        await _open(tester);
        final scroll = find.byType(CustomScrollView).last;
        await tester.scrollUntilVisible(
          find.text('Use mobile data'),
          100,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use mobile data'));
        expect(uploads.mobileData, 1);
        await tester.scrollUntilVisible(
          find.text('Retry uploads'),
          100,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retry uploads'));
        expect(uploads.retries, 1);
        await _preview(tester, 'upload-compact-accessible-${platform.name}');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'standalone panel keeps home-indicator space inside its surface',
    (tester) async {
      await _pump(
        tester,
        _Uploads([_item(0, UploadStatus.uploadingOriginalToTelegram)]),
        navigation: false,
      );
      await _open(tester);
      final panel = tester.getRect(
        find.byKey(const ValueKey('upload-panel-surface')),
      );
      expect(panel.bottom, 874);
      expect(
        panel.bottom - tester.getRect(find.byType(UploadCard)).bottom,
        closeTo(50, 1),
      );
      await _preview(tester, 'upload-compact-no-tabs');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('concurrent operations retain space on a narrow screen', (
    tester,
  ) async {
    await _pump(
      tester,
      _Uploads([_item(0, UploadStatus.uploadingOriginalToTelegram)]),
      width: 320,
      scale: 2,
      deleting: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Uploading 1 file'), findsOneWidget);
    expect(find.text('Deleting 2 items…'), findsOneWidget);
    await _open(tester);
    expect(find.byType(UploadSheet), findsOneWidget);
  });

  testWidgets('cancel, retry, dismiss and completion use controller state', (
    tester,
  ) async {
    final uploads = _Uploads([
      _item(0, UploadStatus.uploadingOriginalToTelegram),
      _item(1, UploadStatus.failed),
      _item(2, UploadStatus.cancelled),
    ]);
    await _pump(
      tester,
      uploads,
      body: ListView(
        children: [
          for (final item in uploads.items) UploadCard(localId: item.localId),
        ],
      ),
    );
    await tester.tap(find.byTooltip('Cancel'));
    expect(uploads.cancelled, ['0']);
    expect(
      tester.getSize(find.byTooltip('Cancel')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Retry uploads'));
    expect(uploads.retries, 1);
    await tester.tap(find.byTooltip('Dismiss').last);
    expect(uploads.removed, ['2']);
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    UploadStatus.uploaded,
    UploadStatus.failed,
    UploadStatus.cancelled,
  ]) {
    testWidgets('collapsed status ${status.name} and semantic reopening', (
      tester,
    ) async {
      final uploads = _Uploads([_item(0, status, ready: false)]);
      final semantics = tester.ensureSemantics();
      await _pump(tester, uploads);
      final title = status == UploadStatus.uploaded
          ? 'Uploads complete'
          : 'Uploads need attention';
      expect(find.text(title), findsOneWidget);
      if (status == UploadStatus.uploaded)
        expect(find.text('Finishing previews…'), findsOneWidget);
      final target = find.bySemanticsLabel(RegExp('Show upload details'));
      expect(
        tester.getSemantics(target),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: tester.getSemantics(target).label,
        ),
      );
      await _open(tester);
      expect(find.text(title), findsWidgets);
      // Minimizing preserves the in-flight queue.
      tester
          .getSemantics(find.bySemanticsLabel('Minimize uploads'))
          .owner!
          .performAction(
            tester.getSemantics(find.bySemanticsLabel('Minimize uploads')).id,
            ui.SemanticsAction.dismiss,
          );
      await tester.pumpAndSettle();
      expect(find.byType(UploadSheet), findsNothing);
      expect(uploads.items, hasLength(1));
      semantics.dispose();
    });
  }
}
