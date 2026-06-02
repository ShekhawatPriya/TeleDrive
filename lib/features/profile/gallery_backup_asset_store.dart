import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/media/gallery_media_scanner.dart';
import '../upload/upload_models.dart';
import 'gallery_backup_asset_models.dart';

export 'gallery_backup_asset_models.dart';

part 'gallery_backup_asset_store_helpers.dart';

class GalleryBackupAssetStore {
  const GalleryBackupAssetStore();

  static const _prefix = 'gallery_backup_assets_v2';
  static const _cap = 8000;
  static const _debounce = Duration(milliseconds: 350);

  static final Map<String, Map<String, GalleryBackupAssetRecord>> _cache = {};
  static final Map<String, Future<Map<String, GalleryBackupAssetRecord>>>
  _loadTasks = {};
  static final Map<String, Timer> _saveTimers = {};
  static final Map<String, Future<void>> _saveChain = {};

  Future<Map<String, GalleryBackupAssetRecord>> load(String scope) async {
    final cached = _cache[scope];
    if (cached != null) {
      return Map<String, GalleryBackupAssetRecord>.from(cached);
    }
    final existingTask = _loadTasks[scope];
    if (existingTask != null) {
      return Map<String, GalleryBackupAssetRecord>.from(await existingTask);
    }
    late final Future<Map<String, GalleryBackupAssetRecord>> tracked;
    tracked = _loadFromStorage(scope).whenComplete(() {
      if (identical(_loadTasks[scope], tracked)) _loadTasks.remove(scope);
    });
    _loadTasks[scope] = tracked;
    return Map<String, GalleryBackupAssetRecord>.from(await tracked);
  }

  Future<Map<String, GalleryBackupAssetRecord>> _loadFromStorage(
    String scope,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(scope));
    final populated = <String, GalleryBackupAssetRecord>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          for (final entry in parsed.entries) {
            try {
              final value = entry.value;
              final json = value is Map
                  ? Map<String, dynamic>.from(value)
                  : <String, dynamic>{};
              populated['${entry.key}'] = GalleryBackupAssetRecord.fromJson(
                json,
              );
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    _cache[scope] = populated;
    return populated;
  }

  Future<Map<String, GalleryBackupAssetRecord>> _ensureCache(
    String scope,
  ) async {
    final cached = _cache[scope];
    if (cached != null) return cached;
    await load(scope);
    return _cache[scope]!;
  }

  bool _isTerminalStatus(GalleryBackupAssetStatus status) =>
      status == GalleryBackupAssetStatus.uploaded ||
      status == GalleryBackupAssetStatus.failed;

  Future<void> mark(
    String scope,
    String fingerprint,
    GalleryBackupAssetStatus status, {
    String? failureCode,
    String? failureMessage,
  }) async {
    final records = await _ensureCache(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = records[fingerprint];
    records[fingerprint] = (existing ?? _empty(fingerprint, now)).copyWith(
      status: status,
      updatedAtMillis: now,
      failureCode: failureCode,
      failureMessage: failureMessage,
      clearFailure: failureCode == null && failureMessage == null,
    );
    await _scheduleSave(scope, terminal: _isTerminalStatus(status));
  }

  Future<void> markMany(
    String scope,
    Iterable<String> fingerprints,
    GalleryBackupAssetStatus status, {
    String? failureCode,
    String? failureMessage,
  }) async {
    final records = await _ensureCache(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final fingerprint in fingerprints) {
      final existing = records[fingerprint];
      records[fingerprint] = (existing ?? _empty(fingerprint, now)).copyWith(
        status: status,
        updatedAtMillis: now,
        failureCode: failureCode,
        failureMessage: failureMessage,
        clearFailure: failureCode == null && failureMessage == null,
      );
    }
    await _scheduleSave(scope, terminal: _isTerminalStatus(status));
  }

  Future<void> mergeAssetMetadata(String scope, GalleryMediaAsset asset) async {
    final records = await _ensureCache(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        records[asset.fingerprint] ?? _empty(asset.fingerprint, now);
    records[asset.fingerprint] = _withAssetMetadata(
      existing,
      asset,
      updatedAtMillis: now,
    );
    await _scheduleSave(scope, terminal: false);
  }

  Future<void> markUploadedAsset(String scope, GalleryMediaAsset asset) async {
    final records = await _ensureCache(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = records[asset.fingerprint];
    final base = existing ?? _empty(asset.fingerprint, now);
    records[asset.fingerprint] = _withAssetMetadata(
      base,
      asset,
      status: GalleryBackupAssetStatus.uploaded,
      updatedAtMillis: now,
      uploadedAtMillis: base.uploadedAtMillis ?? now,
      clearFailure: true,
      clearCleanupFailure: true,
    );
    await _scheduleSave(scope, terminal: true);
  }

  Future<void> markUploadedUploadItem(String scope, UploadItem item) async {
    final fingerprint = item.backupFingerprint;
    if (fingerprint == null || fingerprint.isEmpty) return;
    final records = await _ensureCache(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = records[fingerprint];
    final base = existing ?? _empty(fingerprint, now);
    records[fingerprint] = base.copyWith(
      status: GalleryBackupAssetStatus.uploaded,
      updatedAtMillis: now,
      uploadedAtMillis: base.uploadedAtMillis ?? now,
      contentUri: item.contentUri,
      path: item.path,
      name: item.name,
      sizeBytes: item.size,
      mimeType: item.mimeType,
      mediaType: item.mediaType ?? _mediaTypeFor(item.mimeType),
      sourceKind: item.backupSourceKind,
      relativePath: item.relativePath,
      modifiedAtMillis: item.localModifiedAt?.millisecondsSinceEpoch,
      addedAtMillis: item.addedAtMillis,
      durationMs: item.durationMs,
      clearFailure: true,
      clearCleanupFailure: true,
    );
    await _scheduleSave(scope, terminal: true);
  }

  Future<void> markCleaned(String scope, Iterable<String> fingerprints) async {
    final records = await _ensureCache(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final fingerprint in fingerprints) {
      final existing = records[fingerprint];
      if (existing == null) continue;
      records[fingerprint] = existing.copyWith(
        updatedAtMillis: now,
        cleanedAtMillis: now,
        clearCleanupFailure: true,
      );
    }
    await _scheduleSave(scope, terminal: true);
  }

  Future<void> markCleanupFailed(
    String scope,
    String fingerprint, {
    required String failureCode,
    required String failureMessage,
  }) async {
    final records = await _ensureCache(scope);
    final existing = records[fingerprint];
    if (existing == null) return;
    records[fingerprint] = existing.copyWith(
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      cleanupFailureCode: failureCode,
      cleanupFailureMessage: failureMessage,
    );
    await _scheduleSave(scope, terminal: true);
  }

  Future<void> flushAll() async {
    final scopes = <String>{..._saveTimers.keys, ..._saveChain.keys};
    for (final scope in scopes) {
      _saveTimers.remove(scope)?.cancel();
    }
    final pending = <Future<void>>[];
    for (final scope in scopes) {
      pending.add(_enqueueSave(scope));
    }
    await Future.wait(pending);
  }

  // Visible for testing — resets in-memory cache state between tests.
  static void debugResetCache() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    _saveChain.clear();
    _loadTasks.clear();
    _cache.clear();
  }
}
