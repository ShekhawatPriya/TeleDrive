import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/media/photo_media_loader.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_media_access_service.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

class Identity extends ChangeNotifier implements AuthController {
  @override
  AuthUser? user = const AuthUser(
    userId: 1,
    telegramId: 10,
    firstName: 'Fixture',
  );
  @override
  bool switchingAccount = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Media implements TelegramMediaAccessService {
  @override
  int generation = 0;
  int calls = 0;
  late File original;
  Completer<File?>? pending;
  @override
  Future<File?> downloadForPrivateView(
    DriveFile file, {
    String variant = 'original',
    Duration? timeout,
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    calls++;
    return pending == null ? original : pending!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PendingOriginal implements PhotoMediaLoader {
  final pending = Completer<File>();
  CancelToken? token;
  int calls = 0;
  @override
  Future<File> original(
    DriveFile file,
    CancelToken cancel, {
    ProgressCallback? progress,
  }) {
    calls++;
    token = cancel;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DriveFile item({String modified = '2026-10-01', String? stream}) => DriveFile(
  id: 'video',
  name: 'video.mp4',
  kind: FileKind.video,
  size: 3,
  modifiedAt: modified,
  createdAt: '2026-10-01',
  parentId: null,
  starred: false,
  originalRefAvailable: true,
  streamUrl: stream,
);

void main() {
  late Directory root;
  late Identity auth;
  late Media media;
  late PhotoMediaLoader loader;
  setUp(() async {
    dotenv.testLoad(fileInput: '');
    root = await Directory.systemTemp.createTemp('photo-media-test-');
    auth = Identity();
    media = Media();
    media.original = await File(
      '${root.path}/fixture.mp4',
    ).writeAsBytes([1, 2, 3]);
    loader = PhotoMediaLoader(media, auth, directory: () async => root);
  });
  tearDown(() async {
    auth.dispose();
    await root.delete(recursive: true);
  });
  testWidgets(
    'an image without derivatives uses one cancellable original path',
    (tester) async {
      final source = PendingOriginal();
      final image = DriveFile(
        id: 'image',
        name: 'image.jpg',
        kind: FileKind.image,
        size: 3,
        modifiedAt: '2026-10-01',
        createdAt: '2026-10-01',
        parentId: null,
        starred: false,
        originalRefAvailable: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [photoMediaLoaderProvider.overrideWithValue(source)],
          child: MaterialApp(
            home: PhotoViewerImage(file: image, active: true, onTap: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 1));
      expect(source.calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(source.token!.isCancelled, isTrue);
      source.pending.completeError(StateError('Cancelled fixture'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'a new loader reuses complete local originals before network or stream resolution',
    () async {
      final first = await loader.video(
        item(stream: 'https://unused.invalid/video'),
        CancelToken(),
      );
      expect(media.calls, 1);
      media.pending = Completer();
      final recreated = PhotoMediaLoader(
        media,
        auth,
        directory: () async => root,
      );
      expect(
        await recreated.video(
          item(stream: 'https://unused.invalid/video'),
          CancelToken(),
        ),
        first,
      );
      expect(media.calls, 1);
    },
  );
  test(
    'Telegram account and content revision separate original caches',
    () async {
      final a = await loader.original(item(), CancelToken());
      auth.user = const AuthUser(userId: 1, telegramId: 20, firstName: 'Other');
      final b = await loader.original(item(), CancelToken());
      final c = await loader.original(
        item(modified: '2026-10-02'),
        CancelToken(),
      );
      expect({a.path, b.path, c.path}, hasLength(3));
      expect(media.calls, 3);
    },
  );
  test(
    'an account generation change rejects late originals without publishing a cache file',
    () async {
      media.pending = Completer();
      final pending = loader.original(item(), CancelToken());
      final expectation = expectLater(pending, throwsStateError);
      while (media.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      media.generation +=
          2; // Includes switching away and back to the same identity.
      media.pending!.complete(media.original);
      await expectation;
      expect(await loader.cachedOriginal(item(), CancelToken()), isNull);
    },
  );
  test(
    'cancellation cannot promote partial content or fall back to an HTTP stream',
    () async {
      media.pending = Completer();
      final token = CancelToken();
      final pending = loader.video(
        item(stream: 'https://must-not-fallback.invalid'),
        token,
      );
      final expectation = expectLater(pending, throwsA(isA<DioException>()));
      while (media.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      token.cancel();
      media.pending!.complete(media.original);
      await expectation;
      expect(await loader.cachedOriginal(item(), CancelToken()), isNull);
    },
  );
}
