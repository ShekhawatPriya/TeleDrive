import 'dart:convert';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../utils/stable_hash.dart';

class PendingTelegramCommit {
  const PendingTelegramCommit({
    required this.id,
    required this.backendBaseUrlHash,
    required this.backendUserId,
    required this.telegramUserId,
    required this.batchId,
    required this.fileId,
    required this.localId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.path,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String backendBaseUrlHash;
  final int backendUserId;
  final int telegramUserId;
  final int batchId;
  final int fileId;
  final String localId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String path;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attempts;
  final String? lastError;

  PendingTelegramCommit copyWith({
    DateTime? updatedAt,
    int? attempts,
    String? lastError,
  }) {
    return PendingTelegramCommit(
      id: id,
      backendBaseUrlHash: backendBaseUrlHash,
      backendUserId: backendUserId,
      telegramUserId: telegramUserId,
      batchId: batchId,
      fileId: fileId,
      localId: localId,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      path: path,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'backendBaseUrlHash': backendBaseUrlHash,
    'backendUserId': backendUserId,
    'telegramUserId': telegramUserId,
    'batchId': batchId,
    'fileId': fileId,
    'localId': localId,
    'filename': filename,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'path': path,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  factory PendingTelegramCommit.fromJson(Map<String, dynamic> json) {
    return PendingTelegramCommit(
      id: '${json['id']}',
      backendBaseUrlHash: '${json['backendBaseUrlHash']}',
      backendUserId: _intValue(json['backendUserId']) ?? 0,
      telegramUserId: _intValue(json['telegramUserId']) ?? 0,
      batchId: _intValue(json['batchId']) ?? 0,
      fileId: _intValue(json['fileId']) ?? 0,
      localId: '${json['localId']}',
      filename: '${json['filename']}',
      mimeType: '${json['mimeType']}',
      sizeBytes: _intValue(json['sizeBytes']) ?? 0,
      path: '${json['path']}',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime.now(),
      attempts: _intValue(json['attempts']) ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

class PendingTelegramCommitRetryResult {
  const PendingTelegramCommitRetryResult({
    required this.attempted,
    required this.committed,
    required this.failed,
    this.lastError,
  });

  final int attempted;
  final int committed;
  final int failed;
  final String? lastError;
}

class PendingTelegramCommitQueue {
  PendingTelegramCommitQueue({SecureStorageService? storage})
    : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;
  static final Map<String, Future<void>> _mutationChains = {};

  String activeScope({
    required int backendUserId,
    required int telegramUserId,
  }) {
    return '${stableHash(AppConfig.apiBaseUrl)}_${backendUserId}_$telegramUserId';
  }

  String get backendBaseUrlHash => stableHash(AppConfig.apiBaseUrl);

  Future<int> pendingCount({
    required int backendUserId,
    required int telegramUserId,
  }) async {
    final scope = activeScope(
      backendUserId: backendUserId,
      telegramUserId: telegramUserId,
    );
    return (await list(scope)).length;
  }

  Future<List<PendingTelegramCommit>> list(String scope) async {
    final raw = await _storage.readPendingTelegramCommits(scope);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => PendingTelegramCommit.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((entry) => entry.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String scope, PendingTelegramCommit record) =>
      _mutate(scope, () async {
        final records = await list(scope);
        final next = [
          for (final existing in records)
            if (existing.id != record.id) existing,
          record,
        ];
        await _write(scope, next);
      });

  Future<void> remove(String scope, String id) => _mutate(scope, () async {
    final records = await list(scope);
    final next = records.where((entry) => entry.id != id).toList();
    await _write(scope, next);
  });

  Future<PendingTelegramCommitRetryResult> retryPending({
    required ApiClient api,
    required int backendUserId,
    required int telegramUserId,
  }) async {
    final scope = activeScope(
      backendUserId: backendUserId,
      telegramUserId: telegramUserId,
    );
    final records = await list(scope);
    var committed = 0;
    var failed = 0;
    String? lastError;
    for (final record in records) {
      try {
        await api.dio.post(record.path, data: record.payload);
        await remove(scope, record.id);
        committed++;
      } catch (err) {
        failed++;
        lastError = api.errorMessage(err, 'Metadata commit retry failed.');
        await save(
          scope,
          record.copyWith(
            updatedAt: DateTime.now(),
            attempts: record.attempts + 1,
            lastError: lastError,
          ),
        );
      }
    }
    return PendingTelegramCommitRetryResult(
      attempted: records.length,
      committed: committed,
      failed: failed,
      lastError: lastError,
    );
  }

  Future<void> _write(String scope, List<PendingTelegramCommit> records) async {
    if (records.isEmpty) {
      await _storage.clearPendingTelegramCommits(scope);
      return;
    }
    await _storage.savePendingTelegramCommits(
      scope,
      jsonEncode(records.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _mutate(String scope, Future<void> Function() operation) {
    final previous = _mutationChains[scope] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => operation());
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_mutationChains[scope], tracked)) {
        _mutationChains.remove(scope);
      }
    });
    _mutationChains[scope] = tracked;
    return tracked;
  }
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
