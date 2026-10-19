import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/stable_hash.dart';

/// One time-aware LRU (TLRU) budget. Entries idle longer than [ttl] expire;
/// when the tier exceeds [maxBytes] it evicts least-recently-used entries
/// down to [targetBytes] (high/low watermarks avoid trimming on every write).
@immutable
class MediaCacheBudget {
  const MediaCacheBudget({
    required this.maxBytes,
    required this.targetBytes,
    required this.ttl,
  }) : assert(targetBytes <= maxBytes);

  final int maxBytes;
  final int targetBytes;
  final Duration ttl;
}

/// Disk tiers for Telegram media copies under the temporary directory.
///
/// See docs/media-loading.md, "Media cache tiers". Thumbnails live in
/// `TeleDriveThumbnailCacheManager`; this class owns the larger tiers:
///
/// - previews: `teledrive_<hash>_<name>` files written by the native download
///   bridge (viewer previews and other derivative reads);
/// - originals: `teledrive-downloads/<revision>/` entries from `DownloadCache`.
///
/// Recency is the file modification time; every cache hit [touch]es it, so
/// eviction follows last access rather than first download. Entries touched
/// within [immunity] are never evicted (in-flight or on-screen work), and
/// `.partial`/staging leftovers are swept once stale.
class MediaDiskCache {
  MediaDiskCache({
    Future<Directory> Function()? directory,
    DateTime Function()? clock,
    this.previews = const MediaCacheBudget(
      maxBytes: 256 * _mib,
      targetBytes: 192 * _mib,
      ttl: Duration(days: 14),
    ),
    this.originals = const MediaCacheBudget(
      maxBytes: 1024 * _mib,
      targetBytes: 768 * _mib,
      ttl: Duration(days: 7),
    ),
    this.immunity = const Duration(minutes: 5),
    this.minTrimInterval = const Duration(seconds: 30),
  }) : _directory = directory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  static const _mib = 1024 * 1024;
  static const previewPrefix = 'teledrive_';
  static const originalsDirectory = 'teledrive-downloads';
  static final instance = MediaDiskCache();

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  final MediaCacheBudget previews;
  final MediaCacheBudget originals;
  final Duration immunity;
  final Duration minTrimInterval;
  Future<void>? _trimming;
  DateTime? _lastTrim;

  static String previewFileName(String cacheKey, String filename) {
    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$previewPrefix${stableHash(cacheKey)}_$safeName';
  }

  Future<File> previewFile(String cacheKey, String filename) async {
    final dir = await _directory();
    return File(
      '${dir.path}${Platform.pathSeparator}${previewFileName(cacheKey, filename)}',
    );
  }

  /// Cache-first read: a complete preview copy is returned (and touched)
  /// without any network, TDLib, or account setup. Never throws.
  Future<File?> lookupPreview(String cacheKey, String filename) async {
    try {
      return await hit(await previewFile(cacheKey, filename));
    } catch (_) {
      return null;
    }
  }

  /// Returns [file] when it holds data, after marking it recently used.
  Future<File?> hit(File file) async {
    try {
      if (!await file.exists() || await file.length() <= 0) return null;
      await touch(file);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> touch(File file) async {
    try {
      await file.setLastModified(_clock());
    } catch (_) {
      // Recency is best effort; a failed touch only makes eviction earlier.
    }
  }

  /// Applies both budgets. Single-flight and rate limited unless [force].
  Future<void> trim({bool force = false}) {
    final running = _trimming;
    if (running != null) return running;
    final last = _lastTrim;
    if (!force && last != null && _clock().difference(last) < minTrimInterval) {
      return Future<void>.value();
    }
    final future = _trim().whenComplete(() {
      _lastTrim = _clock();
      _trimming = null;
    });
    _trimming = future;
    return future;
  }

  Future<void> _trim() async {
    try {
      final root = await _directory();
      if (!await root.exists()) return;
      final previewEntries = <_Entry>[];
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = _basename(entity.path);
        if (!name.startsWith(previewPrefix)) continue;
        final stat = await entity.stat();
        if (name.endsWith('.partial')) {
          if (_age(stat.modified) > const Duration(hours: 1)) {
            await _delete(entity);
          }
          continue;
        }
        previewEntries.add(_Entry(entity, stat.size, stat.modified));
      }
      await _apply(previewEntries, previews);

      final originalsRoot = Directory(
        '${root.path}${Platform.pathSeparator}$originalsDirectory',
      );
      if (!await originalsRoot.exists()) return;
      final originalEntries = <_Entry>[];
      await for (final entity in originalsRoot.list(followLinks: false)) {
        if (entity is! Directory) continue;
        var size = 0;
        DateTime? newest;
        var inFlight = false;
        await for (final child in entity.list(
          recursive: true,
          followLinks: false,
        )) {
          if (_basename(child.path).startsWith('.download-')) inFlight = true;
          if (child is! File) continue;
          final stat = await child.stat();
          size += stat.size;
          if (newest == null || stat.modified.isAfter(newest)) {
            newest = stat.modified;
          }
        }
        if (newest == null) {
          if (!inFlight) await _delete(entity);
          continue;
        }
        // A staging directory means DownloadCache.obtain is writing now.
        originalEntries.add(_Entry(entity, size, inFlight ? _clock() : newest));
      }
      await _apply(originalEntries, originals);
    } catch (err) {
      if (kDebugMode) debugPrint('Media cache trim failed: $err');
    }
  }

  Future<void> _apply(List<_Entry> entries, MediaCacheBudget budget) async {
    entries.sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.size);
    final kept = <_Entry>[];
    for (final entry in entries) {
      final age = _age(entry.lastUsed);
      if (age > budget.ttl && age > immunity) {
        await _delete(entry.entity);
        total -= entry.size;
      } else {
        kept.add(entry);
      }
    }
    if (total <= budget.maxBytes) return;
    for (final entry in kept) {
      if (total <= budget.targetBytes) break;
      if (_age(entry.lastUsed) <= immunity) continue;
      await _delete(entry.entity);
      total -= entry.size;
    }
  }

  Duration _age(DateTime time) => _clock().difference(time);

  static String _basename(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);

  static Future<void> _delete(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } catch (_) {
      // Another reader may have removed it already.
    }
  }
}

class _Entry {
  _Entry(this.entity, this.size, this.lastUsed);
  final FileSystemEntity entity;
  final int size;
  final DateTime lastUsed;
}
