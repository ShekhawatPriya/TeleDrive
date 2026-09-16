import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/storage/download_cache.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

DriveFile file(String id, {String name = 'report.pdf'}) => DriveFile(
  id: id,
  name: name,
  kind: FileKind.pdf,
  size: 3,
  modifiedAt: '2026-09-16',
  createdAt: '2026-09-16',
  parentId: null,
  starred: false,
);
void main() {
  test(
    'downloads with identical names are isolated by account, server and id',
    () {
      final cache = DownloadCache(Directory.systemTemp);
      final paths = {
        cache.relativePath('server-a', 1, file('1')),
        cache.relativePath('server-a', 2, file('1')),
        cache.relativePath('server-a', 1, file('2')),
        cache.relativePath('server-b', 1, file('1')),
      };
      expect(paths, hasLength(4));
      expect(
        cache
            .relativePath('server-a', 1, file('1', name: '../../report.pdf'))
            .split('/'),
        hasLength(3),
      );
    },
  );
  test(
    'incomplete download is not reused and a complete file is cached',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'teledrive-cache-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final cache = DownloadCache(root);
      await expectLater(
        cache.obtain(
          backend: 'a',
          userId: 1,
          file: file('1'),
          download: (path) async {
            await File(path).writeAsBytes([1]);
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      final result = await cache.obtain(
        backend: 'a',
        userId: 1,
        file: file('1'),
        download: (path) async {
          await File(path).writeAsBytes([1, 2, 3]);
        },
      );
      expect(await result.readAsBytes(), [1, 2, 3]);
      await cache.obtain(
        backend: 'a',
        userId: 1,
        file: file('1'),
        download: (_) async => fail('Valid cache should be reused'),
      );
      expect(
        await result.parent.list().where((entry) => entry is Directory).length,
        0,
      );
    },
  );
}
