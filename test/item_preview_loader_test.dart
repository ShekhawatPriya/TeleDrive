import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/media/item_preview_loader.dart';
import 'package:flutter_m_fsdk/core/media/thumbnail_loader.dart';
import 'package:flutter_m_fsdk/core/media/thumbnail_scheduler.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

DriveFile file({
  FileKind kind = FileKind.image,
  int size = 100,
  String? thumbnail,
}) => DriveFile(
  id: 'one',
  name: 'Example.pdf',
  kind: kind,
  size: size,
  modifiedAt: '2026-09-17',
  createdAt: '',
  parentId: null,
  starred: false,
  thumbnailUrl: thumbnail,
);

class _Thumbnails implements ThumbnailLoader {
  bool sources = true;
  int loads = 0;
  CancelToken? token;
  final pending = Completer<File?>();
  @override
  bool hasSources(DriveFile file) => sources;
  @override
  bool canUseOriginal(DriveFile file) => false;
  @override
  String keyFor(DriveFile file) => 'scoped-revision';
  @override
  Future<File?> load(
    DriveFile file,
    CancelToken token, {
    bool original = false,
  }) {
    loads++;
    this.token = token;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'preview uses actual local media independent of the file row snapshot',
    () async {
      final thumbs = _Thumbnails();
      final scheduler = ThumbnailScheduler<File>();
      addTearDown(scheduler.dispose);
      final loader = ItemPreviewLoader(
        thumbnails: thumbs,
        scheduler: scheduler,
        document: (_, _) async => throw StateError('not a document'),
      );
      final path = File('test/fixtures/design/alpine.jpg').absolute.path;
      expect(await loader.load(file(thumbnail: path), CancelToken()), {
        'imagePath': path,
      });
      expect(thumbs.loads, 0);
    },
  );
  test(
    'dismissing preview cancels only its waiter and rejects a late image',
    () async {
      final thumbs = _Thumbnails();
      final scheduler = ThumbnailScheduler<File>();
      addTearDown(scheduler.dispose);
      final loader = ItemPreviewLoader(
        thumbnails: thumbs,
        scheduler: scheduler,
        document: (_, _) async => null,
      );
      final token = CancelToken();
      final result = loader.load(file(), token);
      await Future<void>.delayed(Duration.zero);
      expect(thumbs.loads, 1);
      token.cancel();
      expect(await result, isNull);
      expect(thumbs.token!.isCancelled, isTrue);
      thumbs.pending.complete(File('/late-image'));
    },
  );
  test(
    'unsupported and oversized originals never download; PDF uses cancellable private access',
    () async {
      final thumbs = _Thumbnails()..sources = false;
      final scheduler = ThumbnailScheduler<File>();
      addTearDown(scheduler.dispose);
      var downloads = 0;
      final pending = Completer<File?>();
      final loader = ItemPreviewLoader(
        thumbnails: thumbs,
        scheduler: scheduler,
        document: (_, _) {
          downloads++;
          return pending.future;
        },
      );
      expect(
        await loader.load(file(kind: FileKind.other), CancelToken()),
        isNull,
      );
      expect(
        await loader.load(
          file(kind: FileKind.pdf, size: 21000000),
          CancelToken(),
        ),
        isNull,
      );
      expect(downloads, 0);
      final token = CancelToken();
      final result = loader.load(file(kind: FileKind.pdf), token);
      expect(downloads, 1);
      token.cancel('Account changed or preview dismissed');
      pending.complete(File('/scoped/file.pdf'));
      expect(await result, isNull);
    },
  );
}
