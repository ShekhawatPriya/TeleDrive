import 'package:flutter_m_fsdk/features/profile/gallery_backup_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('marks uploaded assets as non-retryable across reloads', () async {
    SharedPreferences.setMockInitialValues({});
    const store = GalleryBackupAssetStore();

    await store.mark(
      'user-1',
      'photo-fingerprint',
      GalleryBackupAssetStatus.uploaded,
    );

    final reloaded = await store.load('user-1');
    final record = reloaded['photo-fingerprint'];

    expect(record, isNotNull);
    expect(record!.status, GalleryBackupAssetStatus.uploaded);
    expect(record.isUploaded, isTrue);
    expect(record.isRetryable, isFalse);
  });

  test('failed assets remain retryable with failure metadata', () async {
    SharedPreferences.setMockInitialValues({});
    const store = GalleryBackupAssetStore();

    await store.mark(
      'user-1',
      'video-fingerprint',
      GalleryBackupAssetStatus.failed,
      failureCode: 'tdlib_unavailable',
      failureMessage: 'Reconnect Telegram on this device.',
    );

    final reloaded = await store.load('user-1');
    final record = reloaded['video-fingerprint'];

    expect(record, isNotNull);
    expect(record!.status, GalleryBackupAssetStatus.failed);
    expect(record.isUploaded, isFalse);
    expect(record.isRetryable, isTrue);
    expect(record.failureCode, 'tdlib_unavailable');
    expect(record.failureMessage, 'Reconnect Telegram on this device.');
  });

  test(
    'markMany restores queued items to discovered without deleting history',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = GalleryBackupAssetStore();

      await store.markMany('user-1', [
        'a',
        'b',
      ], GalleryBackupAssetStatus.queued);
      await store.markMany('user-1', [
        'a',
        'b',
      ], GalleryBackupAssetStatus.discovered);

      final reloaded = await store.load('user-1');

      expect(reloaded.keys, containsAll(['a', 'b']));
      expect(reloaded['a']!.status, GalleryBackupAssetStatus.discovered);
      expect(reloaded['b']!.isRetryable, isTrue);
    },
  );
}
