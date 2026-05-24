import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final String fingerprint;
  final GalleryBackupAssetStatus status;
  final int updatedAtMillis;
  final String? failureCode;
  final String? failureMessage;

  bool get isUploaded => status == GalleryBackupAssetStatus.uploaded;

  DateTime get updatedAt =>
      DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);

  bool get isRetryable =>
      status == GalleryBackupAssetStatus.discovered ||
      status == GalleryBackupAssetStatus.failed ||
      status == GalleryBackupAssetStatus.skipped;

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'status': status.name,
    'updatedAtMillis': updatedAtMillis,
    if (failureCode != null) 'failureCode': failureCode,
    if (failureMessage != null) 'failureMessage': failureMessage,
  };

  factory GalleryBackupAssetRecord.fromJson(Map<String, dynamic> json) {
    return GalleryBackupAssetRecord(
      fingerprint: '${json['fingerprint'] ?? ''}',
      status: GalleryBackupAssetStatus.fromStorage(json['status'] as String?),
      updatedAtMillis:
          (json['updatedAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      failureCode: json['failureCode'] as String?,
      failureMessage: json['failureMessage'] as String?,
    );
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
      return MapEntry(
        '$key',
        GalleryBackupAssetRecord.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      );
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
    records[fingerprint] = GalleryBackupAssetRecord(
      fingerprint: fingerprint,
      status: status,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      failureCode: failureCode,
      failureMessage: failureMessage,
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
      records[fingerprint] = GalleryBackupAssetRecord(
        fingerprint: fingerprint,
        status: status,
        updatedAtMillis: now,
        failureCode: failureCode,
        failureMessage: failureMessage,
      );
    }
    await _save(scope, records);
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
