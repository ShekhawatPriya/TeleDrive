import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/core/telegram/pending_telegram_commit_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes concurrent saves across queue instances', () async {
    final storage = _DelayedSecureStorage();
    final firstQueue = PendingTelegramCommitQueue(storage: storage);
    final secondQueue = PendingTelegramCommitQueue(storage: storage);

    await Future.wait([
      firstQueue.save('scope', _record('first')),
      secondQueue.save('scope', _record('second')),
    ]);

    final records = await firstQueue.list('scope');
    expect(
      records.map((record) => record.id),
      containsAll(['first', 'second']),
    );
    expect(records, hasLength(2));
  });

  test(
    'serializes concurrent removal and save without restoring old data',
    () async {
      final storage = _DelayedSecureStorage();
      final firstQueue = PendingTelegramCommitQueue(storage: storage);
      final secondQueue = PendingTelegramCommitQueue(storage: storage);
      await firstQueue.save('scope', _record('old'));

      await Future.wait([
        firstQueue.remove('scope', 'old'),
        secondQueue.save('scope', _record('new')),
      ]);

      final records = await firstQueue.list('scope');
      expect(records.map((record) => record.id), ['new']);
    },
  );
}

PendingTelegramCommit _record(String id) {
  final now = DateTime(2026, 6, 2);
  return PendingTelegramCommit(
    id: id,
    backendBaseUrlHash: 'hash',
    backendUserId: 1,
    telegramUserId: 2,
    batchId: 3,
    fileId: 4,
    localId: 'local-$id',
    filename: '$id.txt',
    mimeType: 'text/plain',
    sizeBytes: 5,
    path: '/client-uploads/3/file-complete',
    payload: {'id': id},
    createdAt: now,
    updatedAt: now,
  );
}

class _DelayedSecureStorage extends SecureStorageService {
  final Map<String, String> _records = {};

  @override
  Future<String?> readPendingTelegramCommits(String scope) async {
    await Future<void>.delayed(Duration.zero);
    return _records[scope];
  }

  @override
  Future<void> savePendingTelegramCommits(String scope, String value) async {
    await Future<void>.delayed(Duration.zero);
    _records[scope] = value;
  }

  @override
  Future<void> clearPendingTelegramCommits(String scope) async {
    await Future<void>.delayed(Duration.zero);
    _records.remove(scope);
  }
}
