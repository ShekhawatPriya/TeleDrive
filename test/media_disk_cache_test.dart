import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/storage/media_disk_cache.dart';

void main() {
  late Directory root;
  late DateTime now;

  MediaDiskCache cache({
    MediaCacheBudget previews = const MediaCacheBudget(
      maxBytes: 300,
      targetBytes: 200,
      ttl: Duration(days: 14),
    ),
    MediaCacheBudget originals = const MediaCacheBudget(
      maxBytes: 300,
      targetBytes: 200,
      ttl: Duration(days: 7),
    ),
  }) => MediaDiskCache(
    directory: () async => root,
    clock: () => now,
    previews: previews,
    originals: originals,
  );

  Future<File> preview(String name, int bytes, Duration age) async {
    final file = File('${root.path}/${MediaDiskCache.previewPrefix}$name');
    await file.writeAsBytes(List.filled(bytes, 1));
    await file.setLastModified(now.subtract(age));
    return file;
  }

  Future<Directory> original(String revision, int bytes, Duration age) async {
    final dir = Directory(
      '${root.path}/${MediaDiskCache.originalsDirectory}/$revision',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}/photo.jpg');
    await file.writeAsBytes(List.filled(bytes, 1));
    await file.setLastModified(now.subtract(age));
    return dir;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media-disk-cache-');
    now = DateTime(2026, 10, 19, 12);
  });

  tearDown(() => root.delete(recursive: true));

  test('evicts least-recently-used previews to the low watermark', () async {
    final oldest = await preview('a', 100, const Duration(hours: 5));
    final middle = await preview('b', 100, const Duration(hours: 4));
    final newer = await preview('c', 100, const Duration(hours: 3));
    final newest = await preview('d', 100, const Duration(hours: 2));

    await cache().trim(force: true);

    expect(await oldest.exists(), isFalse);
    expect(await middle.exists(), isFalse);
    expect(await newer.exists(), isTrue);
    expect(await newest.exists(), isTrue);
  });

  test('a cache hit refreshes recency so it survives eviction', () async {
    final reread = await preview('a', 100, const Duration(hours: 5));
    final idle = await preview('b', 100, const Duration(hours: 4));
    await preview('c', 100, const Duration(hours: 3));
    await preview('d', 100, const Duration(hours: 2));
    final media = cache();

    expect(await media.hit(reread), isNotNull);
    now = now.add(const Duration(hours: 1));
    await media.trim(force: true);

    expect(await reread.exists(), isTrue);
    expect(await idle.exists(), isFalse);
  });

  test('expires entries idle longer than the TTL under budget', () async {
    final expired = await preview('a', 10, const Duration(days: 15));
    final fresh = await preview('b', 10, const Duration(days: 1));

    await cache().trim(force: true);

    expect(await expired.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });

  test('never evicts recently used entries even over budget', () async {
    final active = await preview('a', 400, const Duration(minutes: 1));

    await cache().trim(force: true);

    expect(await active.exists(), isTrue);
  });

  test('sweeps stale partial copies and ignores unrelated files', () async {
    final partial = await preview('x.partial', 10, const Duration(hours: 2));
    final unrelated = File('${root.path}/picker_upload.jpg');
    await unrelated.writeAsBytes(List.filled(1000, 1));
    await unrelated.setLastModified(now.subtract(const Duration(days: 60)));

    await cache().trim(force: true);

    expect(await partial.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });

  test('trims originals by revision and protects in-flight staging', () async {
    final oldest = await original('r1', 200, const Duration(hours: 5));
    final staging = await original('r2', 200, const Duration(hours: 4));
    await Directory('${staging.path}/.download-abc').create();
    final newest = await original('r3', 200, const Duration(hours: 3));

    await cache().trim(force: true);

    expect(await oldest.exists(), isFalse);
    expect(await staging.exists(), isTrue);
    expect(await newest.exists(), isFalse);
  });

  test('lookup returns only complete preview copies', () async {
    final media = cache();
    final target = await media.previewFile('key', 'a/b.jpg');
    expect(target.path, isNot(contains('a/b.jpg')));
    expect(await media.lookupPreview('key', 'a/b.jpg'), isNull);
    await target.writeAsBytes(const []);
    expect(await media.lookupPreview('key', 'a/b.jpg'), isNull);
    await target.writeAsBytes(const [1, 2, 3]);
    expect((await media.lookupPreview('key', 'a/b.jpg'))?.path, target.path);
  });

  test('trims are rate limited unless forced', () async {
    final media = cache();
    await media.trim(force: true);
    final late = await preview('a', 10, const Duration(days: 30));
    await media.trim();
    expect(await late.exists(), isTrue);
    await media.trim(force: true);
    expect(await late.exists(), isFalse);
  });
}
