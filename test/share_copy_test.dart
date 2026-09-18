import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/models/share_models.dart' as links;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/share/file_copy_share_service.dart';
import 'package:flutter_m_fsdk/features/share/share_flow.dart';
import 'package:flutter_m_fsdk/features/share/components/copy_share_progress_sheet.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const original = DriveFile(
  id: 'one',
  name: 'Original.jpg',
  kind: FileKind.image,
  size: 1000,
  mimeType: 'image/jpeg',
  modifiedAt: 'revision-one',
  createdAt: '',
  parentId: null,
  starred: false,
  storageMode: 'client_managed',
);

class CopyAuth extends ChangeNotifier implements AuthController {
  @override
  AuthUser? user = const AuthUser(userId: 1, telegramId: 10, firstName: 'Test');
  @override
  String? token = 'fixture-token';
  @override
  bool switchingAccount = false;
  void switchTo(int id) {
    user = AuthUser(userId: id, telegramId: id * 10, firstName: 'Test');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CopyFile implements File {
  CopyFile(this.path, {this.bytes = 1000});
  @override
  final String path;
  final int bytes;
  @override
  Future<bool> exists() async => true;
  @override
  Future<int> length() async => bytes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CopyPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  CopyPaths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class CancelledCopySource extends CopyFile {
  CancelledCopySource(this.token) : super('/source');
  final CancelToken token;
  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    yield List.filled(100, 1);
    token.cancel('cancel while staging');
    yield List.filled(900, 1);
  }
}

class CopySettings extends ChangeNotifier implements AppSettingsController {
  CopySettings(this.confirm);
  final bool confirm;
  @override
  AppSettingsState get state => AppSettingsState(confirmPublicShares: confirm);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class CopyLinks extends ChangeNotifier implements ShareController {
  List<links.ShareItemRequest>? requested;
  @override
  Future<links.Share> createShare({
    required List<links.ShareItemRequest> items,
  }) async {
    requested = items;
    throw StateError(
      'Fixture records the request without creating a public link.',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('copy-preview')),
        )
        .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/modernization/share-copy-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> harness(
  WidgetTester tester, {
  required CopyAuth auth,
  required OriginalCopyLoader download,
  required NativeFileShare share,
  TargetPlatform platform = TargetPlatform.iOS,
  Brightness brightness = Brightness.dark,
  CopyLinks? linkController,
  bool confirmLinks = false,
  bool large = false,
  Set<String> folderIds = const {},
  List<DriveFile> files = const [original],
}) async {
  tester.view.physicalSize = Size(large ? 320 : 390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => auth),
        appSettingsControllerProvider.overrideWith(
          (_) => CopySettings(confirmLinks),
        ),
        shareControllerProvider.overrideWith(
          (_) => linkController ?? CopyLinks(),
        ),
        fileCopyShareServiceProvider.overrideWithValue(
          FileCopyShareService(
            auth: auth,
            download: download,
            stage: (source, file, name, token) async =>
                CopyFile('/share/$name'),
          ),
        ),
        nativeFileShareProvider.overrideWithValue(share),
      ],
      child: RepaintBoundary(
        key: const ValueKey('copy-preview'),
        child: MaterialApp(
          theme: buildTheme(
            AppBrand.scheme(brightness),
          ).copyWith(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openItemShare(
                  context,
                  ref,
                  files: files,
                  folderIds: folderIds,
                ),
                child: const Text('Share selection'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Share selection'));
  await tester.pumpAndSettle();
}

Future<void> chooseCopy(WidgetTester tester) async {
  await tester.tap(find.text('Share a copy'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final family in ['Inter', 'Roboto', '.SF Pro Text']) {
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
  test(
    'copies contain original paths, MIME and collision-safe original names',
    () async {
      final auth = CopyAuth();
      final paths = <String>[];
      final service = FileCopyShareService(
        stage: (source, file, name, token) async => CopyFile('/share/$name'),
        auth: auth,
        download: (file, token, progress) async {
          paths.add(file.id);
          progress(500, 1000);
          return CopyFile('/original/${paths.length}');
        },
      );
      final updates = <CopyPreparationProgress>[];
      final files = await service.prepare(
        [original, original.copyWith(name: 'Original.jpg')],
        cancellation: CancelToken(),
        onProgress: updates.add,
      );
      expect(files.map((file) => file.path), [
        '/share/Original.jpg',
        '/share/Original (2).jpg',
      ]);
      expect(files.map((file) => file.name), [
        'Original.jpg',
        'Original (2).jpg',
      ]);
      expect(files.first.mimeType, 'image/jpeg');
      expect(updates.any((value) => value.fraction == .5), isTrue);
    },
  );
  test(
    'account switch away and back cancels a pending batch before next file',
    () async {
      final auth = CopyAuth();
      final pending = Completer<File>();
      var calls = 0;
      final service = FileCopyShareService(
        stage: (source, file, name, token) async => CopyFile('/share/$name'),
        auth: auth,
        download: (_, token, __) {
          calls++;
          return pending.future;
        },
      );
      final future = service.prepare(
        [original, original],
        cancellation: CancelToken(),
        onProgress: (_) {},
      );
      final expectation = expectLater(future, throwsA(isA<DioException>()));
      auth.switchTo(2);
      auth.switchTo(1);
      pending.complete(CopyFile('/original'));
      await expectation;
      expect(calls, 1);
    },
  );
  test(
    'staging preserves real filenames, scopes caches and discards cancelled writes',
    () async {
      final root = await Directory.systemTemp.createTemp('copy-share-test-');
      final oldPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = CopyPaths(root.path);
      try {
        final source = await File(
          '${root.path}/cache-hash.tmp',
        ).writeAsBytes(List.filled(1000, 7));
        final first = await stageOriginalForSharing(
          source,
          original,
          'Original.jpg',
          CancelToken(),
          backend: 'fixture',
          userId: 1,
          telegramId: 10,
        );
        final second = await stageOriginalForSharing(
          source,
          original,
          'Original.jpg',
          CancelToken(),
          backend: 'fixture',
          userId: 2,
          telegramId: 20,
        );
        expect(first.uri.pathSegments.last, 'Original.jpg');
        expect(first.path, isNot(second.path));
        expect(await first.readAsBytes(), await source.readAsBytes());
        final cancellation = CancelToken();
        await expectLater(
          stageOriginalForSharing(
            CancelledCopySource(cancellation),
            original,
            'Cancelled.jpg',
            cancellation,
            backend: 'fixture',
            userId: 1,
            telegramId: 10,
          ),
          throwsA(isA<DioException>()),
        );
        expect(
          await root
              .list(recursive: true)
              .any(
                (file) =>
                    file.path.endsWith('/Cancelled.jpg') ||
                    file.path.endsWith('/payload'),
              ),
          isFalse,
        );
      } finally {
        PathProviderPlatform.instance = oldPaths;
        await root.delete(recursive: true);
      }
    },
  );
  test('cancel and partial originals never yield shareable files', () async {
    final auth = CopyAuth();
    final service = FileCopyShareService(
      stage: (source, file, name, token) async => CopyFile('/share/$name'),
      auth: auth,
      download: (_, __, ___) async => CopyFile('/partial', bytes: 100),
    );
    await expectLater(
      service.prepare(
        [original],
        cancellation: CancelToken(),
        onProgress: (_) {},
      ),
      throwsStateError,
    );
    await expectLater(
      service.prepare(
        [original],
        cancellation: CancelToken()..cancel(),
        onProgress: (_) {},
      ),
      throwsA(isA<DioException>()),
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'choice and cancellable byte progress $platform $brightness',
        (tester) async {
          final auth = CopyAuth();
          final pending = Completer<File>();
          ProgressCallback? report;
          CancelToken? cancellation;
          var shared = 0;
          await harness(
            tester,
            auth: auth,
            platform: platform,
            brightness: brightness,
            large: true,
            download: (_, token, progress) {
              cancellation = token;
              report = progress;
              return pending.future;
            },
            share: (_, __) async {
              shared++;
            },
          );
          expect(find.text('Share a copy'), findsOneWidget);
          expect(find.text('Create link'), findsOneWidget);
          await screenshot(
            tester,
            '${platform.name}-${brightness.name}-choices-large',
          );
          await chooseCopy(tester);
          report!(400, 1000);
          await tester.pump(const Duration(milliseconds: 120));
          expect(find.byType(CopyShareProgressSheet), findsOneWidget);
          expect(
            tester
                .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator),
                )
                .value,
            .4,
          );
          await screenshot(
            tester,
            '${platform.name}-${brightness.name}-progress-large',
          );
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(cancellation!.isCancelled, isTrue);
          pending.complete(CopyFile('/original'));
          await tester.pumpAndSettle();
          expect(shared, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('cached multi-file copy opens one native sheet $platform', (
      tester,
    ) async {
      final shared = <List<XFile>>[];
      await harness(
        tester,
        auth: CopyAuth(),
        platform: platform,
        files: [original, original],
        download: (_, __, ___) async => CopyFile('/original'),
        share: (files, origin) async {
          expect(origin.width, greaterThan(0));
          shared.add(files);
        },
      );
      await chooseCopy(tester);
      expect(shared.single, hasLength(2));
      expect(find.byType(CopyShareProgressSheet), findsNothing);
    });
    testWidgets('folder and mixed selections offer links only $platform', (
      tester,
    ) async {
      var downloads = 0;
      await harness(
        tester,
        auth: CopyAuth(),
        platform: platform,
        folderIds: {'folder'},
        download: (_, __, ___) async {
          downloads++;
          return CopyFile('/original');
        },
        share: (_, __) async {},
      );
      expect(find.text('Share a copy'), findsNothing);
      expect(find.text('Create link'), findsOneWidget);
      expect(downloads, 0);
    });
  }
  testWidgets(
    'mixed link selection retains both item kinds and folder snapshot mode',
    (tester) async {
      final linkController = CopyLinks();
      var downloads = 0;
      await harness(
        tester,
        auth: CopyAuth(),
        linkController: linkController,
        folderIds: {'folder'},
        download: (_, __, ___) async {
          downloads++;
          return CopyFile('/original');
        },
        share: (_, __) async {},
      );
      await tester.tap(find.text('Create link'));
      await tester.pumpAndSettle();
      expect(linkController.requested!.map((item) => item.type), [
        links.ShareItemType.file,
        links.ShareItemType.folder,
      ]);
      expect(
        linkController.requested!.last.mode,
        links.FolderShareMode.snapshot,
      );
      expect(downloads, 0);
    },
  );
  testWidgets(
    'account switch during link confirmation cannot submit old selection',
    (tester) async {
      final auth = CopyAuth();
      final linkController = CopyLinks();
      await harness(
        tester,
        auth: auth,
        linkController: linkController,
        confirmLinks: true,
        download: (_, __, ___) async => CopyFile('/original'),
        share: (_, __) async {},
      );
      await tester.tap(find.text('Create link'));
      for (
        var i = 0;
        i < 10 && find.text('Create public link?').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Create public link?'), findsOneWidget);
      auth.switchTo(2);
      auth.switchTo(1);
      await tester.tap(find.text('Create link'));
      await tester.pumpAndSettle();
      expect(linkController.requested, isNull);
      expect(
        find.text('Account changed. Close and reopen sharing.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('dismissal during download prevents a late native share', (
    tester,
  ) async {
    final pending = Completer<File>();
    var shared = 0;
    await harness(
      tester,
      auth: CopyAuth(),
      download: (_, __, ___) => pending.future,
      share: (_, __) async {
        shared++;
      },
    );
    await chooseCopy(tester);
    await tester.tapAt(const Offset(8, 100));
    // Complete while the dismiss animation is in flight.
    pending.complete(CopyFile('/original'));
    await tester.pumpAndSettle();
    expect(shared, 0);
  });
  testWidgets('download failure retries and never shares partial batches', (
    tester,
  ) async {
    var calls = 0;
    var shared = 0;
    await harness(
      tester,
      auth: CopyAuth(),
      download: (_, __, ___) async {
        if (++calls == 1) throw StateError('offline');
        return CopyFile('/original');
      },
      share: (_, __) async {
        shared++;
      },
    );
    await chooseCopy(tester);
    expect(find.text('Could not prepare files'), findsOneWidget);
    expect(shared, 0);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(shared, 1);
  });
}
