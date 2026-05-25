import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/media/gallery_media_scanner.dart';
import '../upload/upload_models.dart';

enum GalleryBackupAssetStatus {
  discovered,
  queued,
  uploading,
  uploaded,
  failed,
  skipped;

  static GalleryBackupAssetStatus fromStorage(String? value) {
    return GalleryBackupAssetStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => GalleryBackupAssetStatus.discovered,
    );
  }
}

class GalleryBackupAssetRecord {
  const GalleryBackupAssetRecord({
    required this.fingerprint,
    required this.status,
    required this.updatedAtMillis,
    this.failureCode,
    this.failureMessage,
    this.contentUri,
    this.path,
    this.name,
    this.sizeBytes,
    this.mimeType,
    this.mediaType,
    this.sourceKind,
    this.relativePath,
    this.modifiedAtMillis,
    this.addedAtMillis,
    this.durationMs,
    this.uploadedAtMillis,
    this.cleanedAtMillis,
    this.cleanupFailureCode,
    this.cleanupFailureMessage,
  });

  final String fingerprint;
  final GalleryBackupAssetStatus status;
  final int updatedAtMillis;
  final String? failureCode;
  final String? failureMessage;
  final String? contentUri;
  final String? path;
  final String? name;
  final int? sizeBytes;
  final String? mimeType;
  final String? mediaType;
  final String? sourceKind;
  final String? relativePath;
  final int? modifiedAtMillis;
  final int? addedAtMillis;
  final int? durationMs;
  final int? uploadedAtMillis;
  final int? cleanedAtMillis;
  final String? cleanupFailureCode;
  final String? cleanupFailureMessage;

  bool get isUploaded => status == GalleryBackupAssetStatus.uploaded;
  bool get isCleaned => cleanedAtMillis != null;
  bool get hasMediaStoreUri =>
      contentUri != null && contentUri!.startsWith('content://');
  bool get isAutoBackupCleanableHint =>
      isUploaded &&
      !isCleaned &&
      hasMediaStoreUri &&
      sourceKind == 'mediastore' &&
      (sizeBytes ?? 0) > 0;

  DateTime get updatedAt =>
      DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);

  bool get isRetryable =>
      status == GalleryBackupAssetStatus.discovered ||
      status == GalleryBackupAssetStatus.failed ||
      status == GalleryBackupAssetStatus.skipped;

  GalleryBackupAssetRecord copyWith({
    GalleryBackupAssetStatus? status,
    int? updatedAtMillis,
    String? failureCode,
    String? failureMessage,
    bool clearFailure = false,
    String? contentUri,
    String? path,
    String? name,
    int? sizeBytes,
    String? mimeType,
    String? mediaType,
    String? sourceKind,
    String? relativePath,
    int? modifiedAtMillis,
    int? addedAtMillis,
    int? durationMs,
    int? uploadedAtMillis,
    int? cleanedAtMillis,
    bool clearCleanedAt = false,
    String? cleanupFailureCode,
    String? cleanupFailureMessage,
    bool clearCleanupFailure = false,
  }) {
    return GalleryBackupAssetRecord(
      fingerprint: fingerprint,
      status: status ?? this.status,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      failureCode: clearFailure ? null : failureCode ?? this.failureCode,
      failureMessage: clearFailure
          ? null
          : failureMessage ?? this.failureMessage,
      contentUri: contentUri ?? this.contentUri,
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      mediaType: mediaType ?? this.mediaType,
      sourceKind: sourceKind ?? this.sourceKind,
      relativePath: relativePath ?? this.relativePath,
      modifiedAtMillis: modifiedAtMillis ?? this.modifiedAtMillis,
      addedAtMillis: addedAtMillis ?? this.addedAtMillis,
      durationMs: durationMs ?? this.durationMs,
      uploadedAtMillis: uploadedAtMillis ?? this.uploadedAtMillis,
      cleanedAtMillis: clearCleanedAt
          ? null
          : cleanedAtMillis ?? this.cleanedAtMillis,
      cleanupFailureCode: clearCleanupFailure
          ? null
          : cleanupFailureCode ?? this.cleanupFailureCode,
      cleanupFailureMessage: clearCleanupFailure
          ? null
          : cleanupFailureMessage ?? this.cleanupFailureMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'status': status.name,
    'updatedAtMillis': updatedAtMillis,
    if (failureCode != null) 'failureCode': failureCode,
    if (failureMessage != null) 'failureMessage': failureMessage,
    if (contentUri != null) 'contentUri': contentUri,
    if (path != null) 'path': path,
    if (name != null) 'name': name,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if (mimeType != null) 'mimeType': mimeType,
    if (mediaType != null) 'mediaType': mediaType,
    if (sourceKind != null) 'sourceKind': sourceKind,
    if (relativePath != null) 'relativePath': relativePath,
    if (modifiedAtMillis != null) 'modifiedAtMillis': modifiedAtMillis,
    if (addedAtMillis != null) 'addedAtMillis': addedAtMillis,
    if (durationMs != null) 'durationMs': durationMs,
    if (uploadedAtMillis != null) 'uploadedAtMillis': uploadedAtMillis,
    if (cleanedAtMillis != null) 'cleanedAtMillis': cleanedAtMillis,
    if (cleanupFailureCode != null) 'cleanupFailureCode': cleanupFailureCode,
    if (cleanupFailureMessage != null)
      'cleanupFailureMessage': cleanupFailureMessage,
  };

  factory GalleryBackupAssetRecord.fromJson(Map<String, dynamic> json) {
    final fingerprint = '${json['fingerprint'] ?? ''}';
    return GalleryBackupAssetRecord(
      fingerprint: fingerprint,
      status: GalleryBackupAssetStatus.fromStorage(json['status'] as String?),
      updatedAtMillis:
          _intish(json['updatedAtMillis']) ??
          DateTime.now().millisecondsSinceEpoch,
      failureCode: _stringish(json['failureCode']),
      failureMessage: _stringish(json['failureMessage']),
      contentUri: _stringish(json['contentUri']),
      path: _stringish(json['path']),
      name: _stringish(json['name']),
      sizeBytes: _intish(json['sizeBytes']),
      mimeType: _stringish(json['mimeType']),
      mediaType: _stringish(json['mediaType']),
      sourceKind: _stringish(json['sourceKind']),
      relativePath: _stringish(json['relativePath']),
      modifiedAtMillis: _intish(json['modifiedAtMillis']),
      addedAtMillis: _intish(json['addedAtMillis']),
      durationMs: _intish(json['durationMs']),
      uploadedAtMillis: _intish(json['uploadedAtMillis']),
      cleanedAtMillis: _intish(json['cleanedAtMillis']),
      cleanupFailureCode: _stringish(json['cleanupFailureCode']),
      cleanupFailureMessage: _stringish(json['cleanupFailureMessage']),
    );
  }

  static int? _intish(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _stringish(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}

class GalleryBackupAssetStore {
  const GalleryBackupAssetStore();

  static const _prefix = 'gallery_backup_assets_v2';
  static const _cap = 8000;

  Future<Map<String, GalleryBackupAssetRecord>> load(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(scope));
    if (raw == null || raw.isEmpty) return {};
    final parsed = jsonDecode(raw);
    if (parsed is! Map) return {};
    return parsed.map((key, value) {
      final json = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
      return MapEntry('$key', GalleryBackupAssetRecord.fromJson(json));
    });
  }

  Future<void> mark(
    String scope,
    String fingerprint,
    GalleryBackupAssetStatus status, {
    String? failureCode,
    String? failureMessage,
  }) async {
    final records = await load(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = records[fingerprint];
    records[fingerprint] = (existing ?? _empty(fingerprint, now)).copyWith(
      status: status,
      updatedAtMillis: now,
      failureCode: failureCode,
      failureMessage: failureMessage,
      clearFailure: failureCode == null && failureMessage == null,
    );
    await _save(scope, records);
  }

  Future<void> markMany(
    String scope,
    Iterable<String> fingerprints,
    GalleryBackupAssetStatus status, {
    String? failureCode,
    String? failureMessage,
  }) async {
    final records = await load(scope);
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
    await _save(scope, records);
  }

  Future<void> mergeAssetMetadata(String scope, GalleryMediaAsset asset) async {
    final records = await load(scope);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        records[asset.fingerprint] ?? _empty(asset.fingerprint, now);
    records[asset.fingerprint] = _withAssetMetadata(
      existing,
      asset,
      updatedAtMillis: now,
    );
    await _save(scope, records);
  }

  Future<void> markUploadedAsset(String scope, GalleryMediaAsset asset) async {
    final records = await load(scope);
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
    await _save(scope, records);
  }

  Future<void> markUploadedUploadItem(String scope, UploadItem item) async {
    final fingerprint = item.backupFingerprint;
    if (fingerprint == null || fingerprint.isEmpty) return;
    final records = await load(scope);
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
    await _save(scope, records);
  }

  Future<void> markCleaned(String scope, Iterable<String> fingerprints) async {
    final records = await load(scope);
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
    await _save(scope, records);
  }

  Future<void> markCleanupFailed(
    String scope,
    String fingerprint, {
    required String failureCode,
    required String failureMessage,
  }) async {
    final records = await load(scope);
    final existing = records[fingerprint];
    if (existing == null) return;
    records[fingerprint] = existing.copyWith(
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      cleanupFailureCode: failureCode,
      cleanupFailureMessage: failureMessage,
    );
    await _save(scope, records);
  }

  GalleryBackupAssetRecord _withAssetMetadata(
    GalleryBackupAssetRecord record,
    GalleryMediaAsset asset, {
    GalleryBackupAssetStatus? status,
    required int updatedAtMillis,
    int? uploadedAtMillis,
    bool clearFailure = false,
    bool clearCleanupFailure = false,
  }) {
    return record.copyWith(
      status: status,
      updatedAtMillis: updatedAtMillis,
      uploadedAtMillis: uploadedAtMillis,
      contentUri: asset.contentUri,
      path: asset.path,
      name: asset.name,
      sizeBytes: asset.sizeBytes,
      mimeType: asset.mimeType,
      mediaType: asset.mediaType,
      sourceKind: asset.sourceKind,
      relativePath: asset.relativePath,
      modifiedAtMillis: asset.modifiedAtMillis,
      addedAtMillis: asset.addedAtMillis,
      durationMs: asset.durationMs,
      clearFailure: clearFailure,
      clearCleanupFailure: clearCleanupFailure,
    );
  }

  GalleryBackupAssetRecord _empty(String fingerprint, int now) {
    return GalleryBackupAssetRecord(
      fingerprint: fingerprint,
      status: GalleryBackupAssetStatus.discovered,
      updatedAtMillis: now,
    );
  }

  static String _mediaTypeFor(String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('image/')) return 'image';
    return 'unknown';
  }

  Future<void> _save(
    String scope,
    Map<String, GalleryBackupAssetRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = records.values.toList()
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    await prefs.setString(
      _key(scope),
      jsonEncode({
        for (final record in trimmed.take(_cap))
          record.fingerprint: record.toJson(),
      }),
    );
  }

  static String _key(String scope) => '${_prefix}_$scope';
}
