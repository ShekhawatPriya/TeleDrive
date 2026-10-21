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
import 'package:flutter_m_fsdk/features/upload/ui/components/upload_row_transition.dart';
import 'package:flutter_m_fsdk/features/upload/ui/components/upload_status_ring.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_sheet.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_panel_host.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_status_label.dart';
import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';
import 'package:flutter_m_fsdk/core/utils/file_type_detector.dart';
import 'package:flutter_m_fsdk/widgets/file_list_tile.dart';
import 'package:flutter_m_fsdk/widgets/media_thumb.dart';
import 'package:flutter_m_fsdk/widgets/upload_row_status.dart';

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
  Widget? tabBarOverride,
  Color? backdropColor,
  bool reducedMotion = true,
  double scale = 1,
  bool contrast = false,
  Widget? body,
  bool deleting = false,
  ({int completed, int failed, int total})? deleteProgress,
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
              deleteProgress:
                  deleteProgress ??
                  (deleting ? (completed: 1, failed: 0, total: 3) : null),
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
            disableAnimations: reducedMotion,
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
              UploadPanelHost(
                child: Stack(
                  children: [
                    if (backdropColor != null)
                      Positioned.fill(child: ColoredBox(color: backdropColor)),
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
                              leading: const Icon(
                                Icons.insert_drive_file_outlined,
                              ),
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
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 110,
                      child: const BottomActionSystem(showFab: true),
                    ),
                  ],
                ),
              ),
          bottomNavigationBar: body == null && navigation
              ? tabBarOverride ??
                    FloatingPillNavigationBar(
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

/// iOS buttons use title case; Android keeps sentence case.
String _mobileDataLabel(TargetPlatform platform) =>
    platform == TargetPlatform.iOS ? 'Use Mobile Data' : 'Use mobile data';
String _retryLabel(TargetPlatform platform) =>
    platform == TargetPlatform.iOS ? 'Retry Failed' : 'Retry uploads';

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
        expect(find.textContaining('2 of 6 uploaded'), findsWidgets);
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
        await tester.tap(find.text(_mobileDataLabel(platform)));
        expect(uploads.mobileData, 1);
        await _preview(
          tester,
          'upload-accessible-sheet-${platform.name}-${brightness.name}',
        );
        for (
          var attempt = 0;
          attempt < 8 &&
              find.text(_retryLabel(platform)).hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(find.byType(UploadSheet), const Offset(0, -240));
          await tester.pumpAndSettle();
        }
        expect(find.text(_retryLabel(platform)).hitTestable(), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_retryLabel(platform)));
        expect(uploads.retries, 1);
        await _preview(
          tester,
          'upload-accessible-actions-${platform.name}-${brightness.name}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'iOS surface continues behind floating tabs ${brightness.name}',
      (tester) async {
        await _pump(
          tester,
          _Uploads([_item(0, UploadStatus.waitingForWifi)]),
          brightness: brightness,
          backdropColor: const Color(0xFFFF0033),
          tabBarOverride: const SizedBox(
            key: ValueKey('floating-tabs-fixture'),
            height: 98,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66777777),
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                child: Center(
                  child: Text('Drive       Photos       Starred       Shared'),
                ),
              ),
            ),
          ),
        );
        await _open(tester);
        Future<void> checkSurface() async {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('upload-preview')),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final seam = tester
                .getRect(find.byKey(const ValueKey('floating-tabs-fixture')))
                .top
                .round();
            final scheme = Theme.of(
              tester.element(find.byType(UploadSheet)),
            ).colorScheme;
            final argb = iosUploadPanelColors(scheme).page.toARGB32();
            final expected = [
              (argb >> 16) & 255,
              (argb >> 8) & 255,
              argb & 255,
              255,
            ];
            for (final y in [seam - 2, seam + 2, 872]) {
              final offset = (y * image.width + 2) * 4;
              expect(
                bytes.buffer.asUint8List(offset, 4),
                expected,
                reason: 'No exposed page or seam at y=$y',
              );
            }
            image.dispose();
          });
        }

        await checkSurface();
        await _preview(tester, 'upload-continuous-tabs-${brightness.name}');
        await tester.drag(find.text('Uploads'), const Offset(0, -450));
        await tester.pumpAndSettle();
        await checkSurface();
        await _preview(tester, 'upload-continuous-expanded-${brightness.name}');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'iOS panel closes when queue clears and restores the collapsed control',
    (tester) async {
      final uploads = _Uploads([_item(0, UploadStatus.waitingForWifi)]);
      await _pump(tester, uploads);
      await _open(tester);
      uploads.items.clear();
      uploads.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(UploadSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('iOS host can be disposed during its opening animation', (
    tester,
  ) async {
    await _pump(
      tester,
      _Uploads([_item(0, UploadStatus.waitingForWifi)]),
      reducedMotion: false,
    );
    await tester.tap(find.byType(UploadCollapsedBar));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
              closeTo(tester.getRect(nav).bottom, 1),
            );
            final lastRow = find.byType(UploadCard).last;
            expect(
              tester.getRect(nav).top - tester.getRect(lastRow).bottom,
              closeTo(16, 1),
            );
            expect(find.byType(UploadCollapsedBar), findsNothing);
            if (waiting) {
              final button = tester.widget<CupertinoButton>(
                find.ancestor(
                  of: find.text('Use Mobile Data'),
                  matching: find.byType(CupertinoButton),
                ),
              );
              // One tinted capsule action inside the summary card.
              expect(button.color, isNotNull);
              expect(
                tester.getSize(find.byWidget(button)).height,
                greaterThanOrEqualTo(48),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('Use Mobile Data'));
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
              closeTo(tester.getRect(nav).bottom, 1),
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
          find.text(_mobileDataLabel(platform)),
          100,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(_mobileDataLabel(platform)));
        expect(uploads.mobileData, 1);
        await tester.scrollUntilVisible(
          find.text(_retryLabel(platform)),
          100,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(_retryLabel(platform)));
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

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'cancel, retry, dismiss and completion use controller state ${platform.name}',
      (tester) async {
        final uploads = _Uploads([
          _item(0, UploadStatus.uploadingOriginalToTelegram),
          _item(1, UploadStatus.failed),
          _item(2, UploadStatus.cancelled),
        ]);
        await _pump(
          tester,
          uploads,
          platform: platform,
          body: ListView(
            children: [
              for (final item in uploads.items)
                UploadCard(localId: item.localId),
            ],
          ),
        );
        // Android tooltips name the file; iOS rows carry it in semantics.
        final ios = platform == TargetPlatform.iOS;
        final cancel = ios ? 'Cancel' : 'Cancel ${uploads.items[0].name}';
        final dismiss = ios ? 'Dismiss' : 'Dismiss ${uploads.items[2].name}';
        await tester.tap(find.byTooltip(cancel));
        expect(uploads.cancelled, ['0']);
        expect(
          tester.getSize(find.byTooltip(cancel)).height,
          greaterThanOrEqualTo(48),
        );
        if (platform == TargetPlatform.iOS) {
          // iOS retries from the panel's summary card, once for the batch.
          expect(find.text('Retry uploads'), findsNothing);
        } else {
          await tester.tap(find.text('Retry uploads'));
          expect(uploads.retries, 1);
        }
        await tester.tap(find.byTooltip(dismiss).last);
        expect(uploads.removed, ['2']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // Uploading files in the drive list: a stable local picture (video poster or
  // the photo itself) and the shared progress ring. Never a network spinner
  // or a "cloud off" retry mark. Previews: drive-upload-rows-*.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'uploading drive rows stay stable ${platform.name} ${brightness.name}',
        (tester) async {
          UploadItem upload(
            String id,
            String name,
            String mime,
            UploadStatus status, {
            double server = 0,
            String? poster,
            String path = '/fixture/missing.mov',
          }) => UploadItem(
            localId: id,
            uploadClientId: 'u-$id',
            name: name,
            size: 160 * 1024 * 1024,
            mimeType: mime,
            path: path,
            status: status,
            serverProgress: server,
            posterPath: poster,
            addedAt: DateTime(2026, 10, 21, 9),
          );
          final rows = [
            upload(
              'video',
              'image_picker_5A2879E4-9F1C-7307.mov',
              'video/quicktime',
              UploadStatus.uploadingOriginalToTelegram,
              server: .42,
              poster: _photo,
            ),
            upload(
              'photo',
              'Alpine afternoon.jpg',
              'image/jpeg',
              UploadStatus.uploadingOriginalToTelegram,
              server: .8,
              path: _photo,
            ),
            upload(
              'clip',
              'Holiday clip.mov',
              'video/quicktime',
              UploadStatus.queued,
            ),
            upload(
              'doc',
              'September presentation.pdf',
              'application/pdf',
              UploadStatus.waitingForWifi,
            ),
          ];
          Widget list(List<UploadItem> items) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final item in items)
                Builder(
                  builder: (context) {
                    final file = item.toDriveFile(null);
                    return FileListTile(
                      key: ValueKey(item.localId),
                      name: file.name,
                      subtitle:
                          '${formatUploadStatus(file)} · ${formatFileSize(file.size)}',
                      file: file,
                      isOptimistic: true,
                      onTap: () {},
                    );
                  },
                ),
            ],
          );
          // Decode the fixture photo outside the fake-async zone first, so the
          // preview shows the real picture (as on a device).
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          await tester.runAsync(
            () => precacheImage(
              ResizeImage(FileImage(File(_photo)), width: 320),
              tester.element(find.byType(SizedBox).first),
            ),
          );
          final shown = ValueNotifier(rows);
          addTearDown(shown.dispose);
          await _pump(
            tester,
            _Uploads(const []),
            platform: platform,
            brightness: brightness,
            navigation: false,
            body: ValueListenableBuilder(
              valueListenable: shown,
              builder: (_, items, _) => list(items),
            ),
          );
          await tester.pump();
          expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(UploadRowStatus), findsNWidgets(4));
          expect(find.text('Uploading 40% · 160 MB'), findsOneWidget);
          expect(find.text('Queued · 160 MB'), findsOneWidget);
          await _preview(
            tester,
            'drive-upload-rows-${platform.name}-${brightness.name}',
          );

          // Progress rebuilds keep the same thumbnail state: no reload.
          final before = tester.state(find.byType(MediaThumb).first);
          final firstKey = rows.first.toDriveFile(null).modifiedAt;
          shown.value = [
            rows.first.copyWith(serverProgress: .6),
            ...rows.skip(1),
          ];
          await tester.pump();
          expect(shown.value.first.toDriveFile(null).modifiedAt, firstKey);
          expect(find.text('Uploading 56% · 160 MB'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
          expect(tester.state(find.byType(MediaThumb).first), same(before));
          expect(before.mounted, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // Delete and upload status share one floating capsule beside Add.
  // Previews: status-pills-*.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      for (final entry in <String, ({int completed, int failed, int total})>{
        'deleting': (completed: 1, failed: 0, total: 3),
        'deleted': (completed: 1, failed: 0, total: 1),
        'delete-failed': (completed: 3, failed: 1, total: 3),
      }.entries) {
        testWidgets(
          'status pills ${entry.key} ${platform.name} ${brightness.name}',
          (tester) async {
            await _pump(
              tester,
              _Uploads([
                _item(0, UploadStatus.uploaded),
                _item(1, UploadStatus.uploadingOriginalToTelegram),
              ]),
              platform: platform,
              brightness: brightness,
              deleteProgress: entry.value,
            );
            expect(tester.takeException(), isNull);
            await _preview(
              tester,
              'status-pills-${entry.key}-${platform.name}-${brightness.name}',
            );
          },
        );
      }
    }
  }

  // Rows added to an open panel spring in at the back of the list; a row that
  // leaves (cancelled) slides down and its slot closes before it is dropped.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'queue rows animate in and out ${platform.name} reduced=$reduced',
        (tester) async {
          final uploads = _Uploads([
            _item(0, UploadStatus.uploadingOriginalToTelegram),
            _item(1, UploadStatus.queued),
            _item(2, UploadStatus.queued),
          ]);
          await _pump(
            tester,
            uploads,
            platform: platform,
            reducedMotion: reduced,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: UploadSheet(onMinimize: () {}),
            ),
          );
          await tester.pumpAndSettle();
          RenderBox rowBox(String id) =>
              tester.renderObject(find.byKey(ValueKey('row-$id')));
          // The panel's first rows appear with it, unanimated.
          expect(rowBox('0').size.height, greaterThan(40));

          uploads.items = [...uploads.items, _item(3, UploadStatus.queued)];
          uploads.notifyListeners();
          await tester.pump();
          final added = find.byKey(const ValueKey('row-3'));
          expect(added, findsOneWidget);
          if (!reduced) {
            expect(tester.widget<UploadRowTransition>(added).animateIn, isTrue);
            expect(rowBox('3').size.height, lessThan(4));
            await tester.pump(UploadRowTransition.enterDuration ~/ 2);
            expect(rowBox('3').size.height, greaterThan(4));
          }
          await tester.pumpAndSettle();
          expect(rowBox('3').size.height, greaterThan(40));
          // New rows join the back of the list.
          expect(
            tester.getTopLeft(added).dy,
            greaterThan(
              tester.getTopLeft(find.byKey(const ValueKey('row-2'))).dy,
            ),
          );

          final leaving = uploads.items[1].copyWith(
            status: UploadStatus.cancelled,
          );
          uploads.items = [uploads.items[0], leaving, ...uploads.items.skip(2)];
          uploads.notifyListeners();
          await tester.pump();
          uploads.items = uploads.items.where((i) => i.localId != '1').toList();
          uploads.notifyListeners();
          await tester.pump();
          if (!reduced) {
            // Still on screen, showing its final state while it leaves.
            expect(find.byKey(const ValueKey('row-1')), findsOneWidget);
            expect(find.textContaining('Cancelled'), findsOneWidget);
            await tester.pump(UploadRowTransition.exitDuration ~/ 2);
            expect(find.byKey(const ValueKey('row-1')), findsOneWidget);
          }
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('row-1')), findsNothing);
          expect(find.byKey(const ValueKey('row-3')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // The floating status pill beside Add, in every state and theme, plus the
  // narrow/large-text case. Previews: upload-pill-*.
  final pillStates = <String, List<UploadStatus>>{
    'uploading': [
      UploadStatus.uploaded,
      UploadStatus.uploadingOriginalToTelegram,
      UploadStatus.queued,
    ],
    'wifi': [UploadStatus.waitingForWifi, UploadStatus.waitingForWifi],
    'complete': [UploadStatus.uploaded, UploadStatus.uploaded],
    'attention': [UploadStatus.uploaded, UploadStatus.failed],
  };
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      for (final entry in pillStates.entries) {
        testWidgets(
          'status pill ${entry.key} ${platform.name} ${brightness.name}',
          (tester) async {
            await _pump(
              tester,
              _Uploads([
                for (var i = 0; i < entry.value.length; i++)
                  _item(i, entry.value[i]),
              ]),
              platform: platform,
              brightness: brightness,
            );
            final pill = find.byType(UploadCollapsedBar);
            expect(pill, findsOneWidget);
            expect(tester.getSize(pill).height, greaterThanOrEqualTo(48));
            await _preview(
              tester,
              'upload-pill-${platform.name}-${entry.key}-${brightness.name}',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('dragging the iOS status pill upward expands the panel', (
    tester,
  ) async {
    await _pump(
      tester,
      _Uploads([_item(0, UploadStatus.uploadingOriginalToTelegram)]),
    );
    final pill = find.byType(UploadCollapsedBar);
    // A short downward nudge springs back without opening anything.
    await tester.drag(pill, const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(find.byType(UploadSheet), findsNothing);
    expect(pill, findsOneWidget);
    await tester.drag(pill, const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(find.byType(UploadSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status pill fits 320 points at 200% text', (tester) async {
    await _pump(
      tester,
      _Uploads([
        _item(0, UploadStatus.uploaded),
        _item(1, UploadStatus.uploadingOriginalToTelegram),
      ]),
      width: 320,
      scale: 2,
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
    await _preview(tester, 'upload-pill-iOS-accessible');
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
      // The iOS capsule names the count; the panel keeps the full title.
      final title = status == UploadStatus.uploaded
          ? 'Uploads complete'
          : '1 file not uploaded';
      // The iOS panel's summary card uses the same concise title.
      final panelTitle = title;
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
      expect(find.text(panelTitle), findsWidgets);
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
