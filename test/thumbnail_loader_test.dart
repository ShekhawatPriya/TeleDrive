import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_m_fsdk/core/media/thumbnail_loader.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_test/flutter_test.dart';

DriveFile photo({String? url, int version = 1}) => DriveFile(
  id: '1',
  name: 'photo.jpg',
  kind: FileKind.image,
  size: 50,
  createdAt: '2026-09-01',
  modifiedAt: '2026-09-01',
  parentId: null,
  starred: false,
  thumbnailRefAvailable: true,
  thumbnailVersion: version,
  thumbnailUrl: url,
  originalRefAvailable: true,
);

class _Cache implements BaseCacheManager {
  _Cache(this.root);
  final Directory root;
  final entries = <String, FileInfo>{};
  int writes = 0;
  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => entries[key];
  @override
  Future<fs.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    writes++;
    final file = const LocalFileSystem().file('${root.path}/${key ?? url}');
    await file.writeAsBytes(fileBytes);
    entries[key ?? url] = FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(maxAge),
      url,
    );
    return file;
  }

  @override
  Future<void> removeFile(String key) async {
    entries.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenResponse implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('not an image', 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Cache cache;
  final fixture = File('test/fixtures/design/alpine.jpg');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('thumbnail-test-');
    cache = _Cache(directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  testWidgets('cold load persists; warm and recreated loaders avoid Telegram', (
    tester,
  ) async {
    await tester.runAsync(() async {
      var calls = 0;
      ThumbnailLoader loader(String scope) => ThumbnailLoader(
        scope: scope,
        cache: cache,
        telegram: (_, variant, __) async {
          calls++;
          expect(variant, 'thumbnail');
          return fixture;
        },
      );
      final first = loader('backend:user1:telegram1');
      final cold = await first.load(photo(), CancelToken());
      expect(cold, isNotNull);
      expect(await first.load(photo(), CancelToken()), cold);
      final restarted = loader('backend:user1:telegram1');
      expect((await restarted.load(photo(), CancelToken()))!.path, cold!.path);
      expect(calls, 1);
      expect(cache.writes, 1);
      final otherAccount = loader('backend:user2:telegram2');
      expect(
        (await otherAccount.load(photo(), CancelToken()))!.path,
        isNot(cold.path),
      );
      await restarted.load(photo(version: 2), CancelToken());
      expect(calls, 3);
      first.dispose();
      restarted.dispose();
      otherAccount.dispose();
    });
  });

  testWidgets(
    'corrupt HTTP source advances to direct derivative and is not cached',
    (tester) async {
      await tester.runAsync(() async {
        final http = Dio()..httpClientAdapter = _BrokenResponse();
        var calls = 0;
        final loader = ThumbnailLoader(
          scope: 'scope',
          cache: cache,
          http: http,
          telegram: (_, variant, __) async {
            calls++;
            return fixture;
          },
        );
        final result = await loader.load(
          photo(url: 'https://example.test/thumb'),
          CancelToken(),
        );
        expect(result, isNotNull);
        expect(calls, 1);
        expect(cache.writes, 1);
        expect(await result!.length(), await fixture.length());
        loader.dispose();
      });
    },
  );

  testWidgets('failure is retryable and cancellation never stores late data', (
    tester,
  ) async {
    await tester.runAsync(() async {
      var calls = 0;
      final token = CancelToken();
      final loader = ThumbnailLoader(
        scope: 'scope',
        cache: cache,
        telegram: (_, __, ___) async {
          calls++;
          if (calls == 1) throw StateError('offline');
          if (calls == 2) token.cancel();
          return fixture;
        },
      );
      expect(await loader.load(photo(), CancelToken()), isNull);
      await expectLater(
        loader.load(photo(), token),
        throwsA(isA<DioException>()),
      );
      expect(cache.writes, 0);
      expect(await loader.load(photo(), CancelToken()), isNotNull);
      expect(cache.writes, 1);
      loader.dispose();
    });
  });

  test(
    'cache identity ignores rotating credentials but respects content revisions',
    () {
      final loader = ThumbnailLoader(
        scope: 'backend:1:10',
        cache: cache,
        telegram: (_, __, ___) async => null,
      );
      addTearDown(loader.dispose);
      expect(
        loader.keyFor(photo(url: 'https://example.test/thumb?token=old&v=1')),
        loader.keyFor(photo(url: 'https://example.test/thumb?token=new&v=1')),
      );
      expect(
        loader.keyFor(photo(version: 1)),
        isNot(loader.keyFor(photo(version: 2))),
      );
    },
  );
}
