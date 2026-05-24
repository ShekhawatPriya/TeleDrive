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
}
