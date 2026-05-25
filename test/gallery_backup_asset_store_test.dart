import 'dart:convert';

import 'package:flutter_m_fsdk/core/media/gallery_media_scanner.dart';
import 'package:flutter_m_fsdk/features/profile/gallery_backup_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(GalleryBackupAssetStore.debugResetCache);

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

  test(
    'old JSON parses and old uploaded records are not cleanable hints',
    () async {
      SharedPreferences.setMockInitialValues({
        'gallery_backup_assets_v2_user-1': jsonEncode({
          'old-fp': {
            'fingerprint': 'old-fp',
            'status': 'uploaded',
            'updatedAtMillis': 123,
          },
        }),
      });
      const store = GalleryBackupAssetStore();

      final reloaded = await store.load('user-1');
      final record = reloaded['old-fp'];

      expect(record, isNotNull);
      expect(record!.isUploaded, isTrue);
      expect(record.hasMediaStoreUri, isFalse);
      expect(record.isAutoBackupCleanableHint, isFalse);
    },
  );

  test('new metadata round-trips through storage', () async {
    SharedPreferences.setMockInitialValues({});
    const store = GalleryBackupAssetStore();

    await store.markUploadedAsset('user-1', _asset());
    final reloaded = await store.load('user-1');
    final record = reloaded[_asset().fingerprint]!;

    expect(record.contentUri, 'content://media/external/images/media/10');
    expect(record.name, 'camera.jpg');
    expect(record.sizeBytes, 400);
    expect(record.mimeType, 'image/jpeg');
    expect(record.mediaType, 'image');
    expect(record.sourceKind, 'mediastore');
    expect(record.relativePath, 'DCIM/Camera/');
    expect(record.modifiedAtMillis, 1000);
    expect(record.addedAtMillis, 900);
    expect(record.durationMs, isNull);
    expect(record.uploadedAtMillis, isNotNull);
    expect(record.isAutoBackupCleanableHint, isTrue);
  });

  test('markCleaned preserves upload metadata', () async {
    SharedPreferences.setMockInitialValues({});
    const store = GalleryBackupAssetStore();
    final asset = _asset();

    await store.markUploadedAsset('user-1', asset);
    await store.markCleaned('user-1', [asset.fingerprint]);

    final record = (await store.load('user-1'))[asset.fingerprint]!;
    expect(record.isCleaned, isTrue);
    expect(record.contentUri, asset.contentUri);
    expect(record.sizeBytes, asset.sizeBytes);
    expect(record.isAutoBackupCleanableHint, isFalse);
  });

  test(
    'markCleanupFailed preserves metadata and does not mark cleaned',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = GalleryBackupAssetStore();
      final asset = _asset();

      await store.markUploadedAsset('user-1', asset);
      await store.markCleanupFailed(
        'user-1',
        asset.fingerprint,
        failureCode: 'android_delete_failed',
        failureMessage: 'Android could not remove this local media item.',
      );

      final record = (await store.load('user-1'))[asset.fingerprint]!;
      expect(record.isCleaned, isFalse);
      expect(record.cleanupFailureCode, 'android_delete_failed');
      expect(record.contentUri, asset.contentUri);
    },
  );
}

GalleryMediaAsset _asset() => const GalleryMediaAsset(
  id: 'image:10',
  contentUri: 'content://media/external/images/media/10',
  name: 'camera.jpg',
  sizeBytes: 400,
  mimeType: 'image/jpeg',
  mediaType: 'image',
  modifiedAtMillis: 1000,
  addedAtMillis: 900,
  sourceKind: 'mediastore',
  relativePath: 'DCIM/Camera/',
  path: '/storage/emulated/0/DCIM/Camera/camera.jpg',
);
