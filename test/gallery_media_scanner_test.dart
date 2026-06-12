import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/core/media/gallery_media_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('teledrive/media');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'scanRecent forwards strategy, filters invalid rows, and dedupes paths',
    () async {
      Object? strategy;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'listGalleryMedia');
            strategy = call.arguments['strategy'];
            return [
              {
                'id': '10',
                'contentUri': 'content://media/image/10',
                'name': 'camera.jpg',
                'sizeBytes': 400,
                'mimeType': 'image/jpeg',
                'mediaType': 'image',
                'modifiedAtMillis': 1000,
                'addedAtMillis': 3000,
                'sourceKind': 'mediastore',
                'relativePath': 'DCIM/Camera/',
                'path': r'C:\DCIM\Camera\camera.jpg',
              },
              {
                'id': 'path-10',
                'contentUri': r'C:\DCIM\Camera\camera.jpg',
                'name': 'camera.jpg',
                'sizeBytes': 400,
                'mimeType': 'image/jpeg',
                'mediaType': 'image',
                'modifiedAtMillis': 1000,
                'addedAtMillis': 0,
                'sourceKind': 'path',
                'path': r'C:\DCIM\Camera\camera.jpg',
              },
              {
                'id': '11',
                'contentUri': 'content://media/video/11',
                'name': 'clip.mp4',
                'sizeBytes': 800,
                'mimeType': 'video/mp4',
                'mediaType': 'video',
                'modifiedAtMillis': 2000,
                'addedAtMillis': 1000,
                'sourceKind': 'mediastore',
              },
              {
                'id': 'invalid',
                'contentUri': '',
                'name': 'broken.jpg',
                'sizeBytes': 0,
                'mimeType': 'image/jpeg',
                'mediaType': 'image',
                'modifiedAtMillis': 4000,
                'addedAtMillis': 4000,
                'sourceKind': 'mediastore',
              },
            ];
          });

      const scanner = GalleryMediaScanner(mediaChannel: channel);
      final result = await scanner.scanRecent(
        limit: 10,
        strategy: 'media_store_and_file_path',
      );

      expect(strategy, 'media_store_and_file_path');
      expect(result.invalidSkipCount, 1);
      expect(result.mediaStoreCount, 2);
      expect(result.pathCount, 1);
      expect(result.mergedCount, 2);
      expect(result.assets.map((asset) => asset.id), ['10', '11']);
      expect(result.assets.first.sourceKind, 'mediastore');
    },
  );

  test(
    'deleteMediaUris filters unsafe URIs and parses platform result',
    () async {
      Object? sentUris;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'deleteGalleryMedia');
            sentUris = call.arguments['contentUris'];
            return {
              'requested': 1,
              'deleted': 1,
              'failed': 0,
              'userCancelled': false,
              'deletedUris': ['content://media/external/images/media/10'],
              'failedUris': [],
            };
          });

      const scanner = GalleryMediaScanner(mediaChannel: channel);
      final result = await scanner.deleteMediaUris([
        'content://media/external/images/media/10',
        'content://media/external/images/media',
        'content://com.android.providers.media.documents/document/image%3A10',
        'file:///sdcard/DCIM/camera.jpg',
      ]);

      expect(sentUris, ['content://media/external/images/media/10']);
      expect(result.requested, 1);
      expect(result.deleted, 1);
      expect(result.failed, 0);
      expect(result.userCancelled, isFalse);
    },
  );

  test('isConcreteMediaStoreContentUri accepts iOS phasset URIs', () {
    expect(
      GalleryMediaScanner.isConcreteMediaStoreContentUri(
        'phasset://image/8B3D2F5A-1C7E-4F2B-9D6A-0123456789AB/L0/001',
      ),
      isTrue,
    );
    expect(
      GalleryMediaScanner.isConcreteMediaStoreContentUri(
        'phasset://video/8B3D2F5A-1C7E-4F2B-9D6A-0123456789AB/L0/001',
      ),
      isTrue,
    );
    // Missing identifier or unknown media type must be rejected.
    expect(
      GalleryMediaScanner.isConcreteMediaStoreContentUri('phasset://image/'),
      isFalse,
    );
    expect(
      GalleryMediaScanner.isConcreteMediaStoreContentUri('phasset://audio/id'),
      isFalse,
    );
    // Android URIs still validate as before.
    expect(
      GalleryMediaScanner.isConcreteMediaStoreContentUri(
        'content://media/external/images/media/10',
      ),
      isTrue,
    );
    expect(
      GalleryMediaScanner.isConcreteMediaStoreContentUri(
        'content://media/external/images/media',
      ),
      isFalse,
    );
  });

  test('deleteMediaUris forwards phasset URIs to the platform', () async {
    Object? sentUris;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sentUris = call.arguments['contentUris'];
          return {
            'requested': 1,
            'deleted': 1,
            'failed': 0,
            'userCancelled': false,
            'deletedUris': ['phasset://image/ABC-123/L0/001'],
            'failedUris': [],
          };
        });

    const scanner = GalleryMediaScanner(mediaChannel: channel);
    final result = await scanner.deleteMediaUris([
      'phasset://image/ABC-123/L0/001',
      'phasset://image/',
      'file:///var/mobile/photo.jpg',
    ]);

    expect(sentUris, ['phasset://image/ABC-123/L0/001']);
    expect(result.deleted, 1);
    expect(result.deletedUris, ['phasset://image/ABC-123/L0/001']);
  });

  test(
    'deleteMediaUris returns no-op when no safe MediaStore item URI exists',
    () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            called = true;
            return null;
          });

      const scanner = GalleryMediaScanner(mediaChannel: channel);
      final result = await scanner.deleteMediaUris([
        r'C:\DCIM\Camera\camera.jpg',
        'content://media/external/images/media',
      ]);

      expect(called, isFalse);
      expect(result.requested, 0);
      expect(result.deleted, 0);
      expect(result.failed, 0);
    },
  );
}
