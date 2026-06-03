import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/media/media_source_resolver.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_models.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository_models.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: '');
  });

  group('drive media parsing', () {
    test('parses snake_case legacy rows and synthesizes server URLs', () {
      final api = ApiClient()..setToken('test-token');
      final repo = DriveRepository(api);

      final snapshot = repo.parseDriveState({
        'files': [
          {
            'id': 42,
            'original_filename': 'legacy.jpg',
            'mime_type': 'image/jpeg',
            'upload_status': 'available',
            'thumbnail_status': 'available',
            'preview_status': 'available',
            'thumbnail_version': '2',
            'preview_version': 3,
            'size_bytes': '128',
            'folder_id': 7,
            'is_starred': 'true',
            'is_shared': 1,
            'width_px': '640',
            'height_px': 480,
            'updated_at': '2026-06-01T00:00:00Z',
            'created_at': '2026-05-31T00:00:00Z',
          },
        ],
        'media_files': [],
        'folders': [],
      });

      final file = snapshot.files.single;
      expect(file.name, 'legacy.jpg');
      expect(file.mimeType, 'image/jpeg');
      expect(file.storageMode, isNull);
      expect(file.mediaAccessMode, isNull);
      expect(file.isClientManaged, isFalse);
      expect(file.starred, isTrue);
      expect(file.shared, isTrue);
      expect(file.size, 128);
      expect(file.parentId, '7');
      expect(file.widthPx, 640);
      expect(file.heightPx, 480);
      expect(file.thumbnailUrl, contains('/files/42/thumbnail'));
      expect(file.thumbnailUrl, contains('v=2'));
      expect(file.previewUrl, contains('/files/42/preview'));
      expect(file.previewUrl, contains('v=3'));
      expect(file.streamUrl, contains('/files/42/stream'));
      expect(file.downloadUrl, contains('/files/42/download'));
    });

    test(
      'does not synthesize server URLs for explicit client-managed rows',
      () {
        final repo = DriveRepository(ApiClient());

        final snapshot = repo.parseDriveState({
          'files': [
            {
              'id': 9,
              'originalFilename': 'private.jpg',
              'mimeType': 'image/jpeg',
              'uploadStatus': 'available',
              'storage_mode': 'client_managed',
              'media_access_mode': 'client_direct',
              'thumbnail_status': 'available',
              'preview_status': 'available',
              'original_ref_available': true,
            },
          ],
        });

        final file = snapshot.files.single;
        expect(file.isClientManaged, isTrue);
        expect(file.originalRefAvailable, isTrue);
        expect(file.thumbnailUrl, isNull);
        expect(file.previewUrl, isNull);
        expect(file.streamUrl, isNull);
        expect(file.downloadUrl, isNull);
      },
    );

    test('mediaRef parses snake_case response envelope and refs', () async {
      final api = ApiClient();
      api.dio.httpClientAdapter = _JsonAdapter((options) {
        expect(options.path, '/files/42/media-ref');
        expect(options.queryParameters['variant'], 'preview');
        return {
          'telegram_ref': {
            'variant': 'preview',
            'tdlib_chat_id': '-1001',
            'tdlib_message_id': '123',
            'tdlib_file_id': 456,
            'tdlib_remote_file_id': 'remote-id',
          },
          'fallback_url': 'https://cdn.example/preview.jpg',
          'cache_key': 'file-42-preview',
        };
      });

      final media = await DriveRepository(
        api,
      ).mediaRef('42', variant: 'preview');

      expect(media.cacheKey, 'file-42-preview');
      expect(media.fallbackUrl, 'https://cdn.example/preview.jpg');
      expect(media.ref?.variant, 'preview');
      expect(media.ref?.tdlibChatId, -1001);
      expect(media.ref?.tdlibMessageId, 123);
      expect(media.ref?.tdlibFileId, 456);
      expect(media.ref?.tdlibRemoteFileId, 'remote-id');
    });
  });

  test('Telegram refs and upload targets parse snake_case identifiers', () {
    final ref = TelegramMediaRef.fromJson({
      'storage_backend': 'telegram',
      'client_provider': 'tdlib',
      'server_provider': 'telethon',
      'tdlib_chat_id': '-1002',
      'tdlib_message_id': '22',
      'tdlib_file_id': '33',
      'tdlib_remote_file_id': 'remote',
      'telethon_peer_id': '44',
      'telethon_message_id': 55,
      'telethon_access_hash': '66',
      'telegram_dc_id': '4',
    });

    expect(ref.storageBackend, 'telegram');
    expect(ref.clientProvider, 'tdlib');
    expect(ref.serverProvider, 'telethon');
    expect(ref.tdlibChatId, -1002);
    expect(ref.tdlibMessageId, 22);
    expect(ref.tdlibFileId, 33);
    expect(ref.tdlibRemoteFileId, 'remote');
    expect(ref.telethonPeerId, 44);
    expect(ref.telethonMessageId, 55);
    expect(ref.telethonAccessHash, 66);
    expect(ref.telegramDcId, 4);

    final target = TelegramUploadTarget.fromJson({
      'folder_id': '8',
      'telethon_peer_id': '9',
      'telethon_access_hash': '10',
      'telethon_channel_id': '11',
      'tdlib_chat_id': '-10011',
      'title': 'Uploads',
      'requires_client_resolution': 'false',
    });

    expect(target.folderId, 8);
    expect(target.telethonPeerId, 9);
    expect(target.telethonAccessHash, 10);
    expect(target.telethonChannelId, 11);
    expect(target.tdlibChatId, -10011);
    expect(target.requiresClientResolution, isFalse);
  });

  test('backend feature flags parse snake_case booleans', () {
    final flags = BackendFeatureFlags.fromJson({
      'direct_telegram_upload_enabled': 'true',
      'direct_telegram_download_enabled': 1,
      'client_derivative_generation_enabled': true,
      'gallery_backup_enabled': 'yes',
      'public_proxy_enabled': 'false',
    });

    expect(flags.directTelegramUploadEnabled, isTrue);
    expect(flags.directTelegramDownloadEnabled, isTrue);
    expect(flags.clientDerivativeGenerationEnabled, isTrue);
    expect(flags.galleryBackupEnabled, isTrue);
    expect(flags.publicProxyEnabled, isFalse);
  });

  test('media resolver orders image and video fallbacks', () {
    final image = _driveFile(
      kind: FileKind.image,
      thumbnailUrl: 'https://cdn.example/thumb.jpg',
      previewUrl: 'https://cdn.example/preview.jpg',
      thumbnailRefAvailable: true,
      previewRefAvailable: true,
      originalRefAvailable: true,
    );

    expect(MediaSourceResolver.imageUrls(image, MediaImageUse.thumbnail), [
      'https://cdn.example/thumb.jpg',
      'https://cdn.example/preview.jpg',
    ]);
    expect(
      MediaSourceResolver.imageTelegramVariants(image, MediaImageUse.thumbnail),
      ['thumbnail', 'preview', 'original'],
    );
    expect(
      MediaSourceResolver.imageTelegramVariants(image, MediaImageUse.fullImage),
      ['preview', 'thumbnail', 'original'],
    );

    final video = _driveFile(kind: FileKind.video, originalRefAvailable: true);
    expect(
      MediaSourceResolver.imageTelegramVariants(video, MediaImageUse.thumbnail),
      isEmpty,
    );
    expect(MediaSourceResolver.canDownloadVideoOriginal(video), isTrue);
  });

  test(
    'empty direct derivative payloads do not mark media thumbnails ready',
    () {
      final image = _uploadItem(name: 'photo.jpg', mimeType: 'image/jpeg');
      final video = _uploadItem(name: 'clip.mp4', mimeType: 'video/mp4');
      final text = _uploadItem(name: 'note.txt', mimeType: 'text/plain');

      expect(directDerivativePayloadsReady(image, {}), isFalse);
      expect(directDerivativePayloadsReady(video, {}), isFalse);
      expect(
        directDerivativePayloadsReady(image, {
          'thumbnail': {'tdlib_file_id': '1'},
        }),
        isTrue,
      );
      expect(
        directDerivativePayloadsReady(video, {
          'preview': {'tdlib_file_id': '2'},
        }),
        isTrue,
      );
      expect(directDerivativePayloadsReady(text, {}), isTrue);
    },
  );
}

DriveFile _driveFile({
  required FileKind kind,
  String? thumbnailUrl,
  String? previewUrl,
  String? streamUrl,
  bool originalRefAvailable = false,
  bool thumbnailRefAvailable = false,
  bool previewRefAvailable = false,
}) {
  return DriveFile(
    id: 'file-1',
    name: kind == FileKind.video ? 'clip.mp4' : 'photo.jpg',
    kind: kind,
    size: 128,
    modifiedAt: '2026-06-01T00:00:00Z',
    createdAt: '2026-06-01T00:00:00Z',
    parentId: null,
    starred: false,
    mimeType: kind == FileKind.video ? 'video/mp4' : 'image/jpeg',
    uploadStatus: 'available',
    originalRefAvailable: originalRefAvailable,
    thumbnailRefAvailable: thumbnailRefAvailable,
    previewRefAvailable: previewRefAvailable,
    thumbnailUrl: thumbnailUrl,
    previewUrl: previewUrl,
    streamUrl: streamUrl,
  );
}

UploadItem _uploadItem({required String name, required String mimeType}) {
  return UploadItem(
    localId: 'local-$name',
    uploadClientId: 'upload-$name',
    name: name,
    size: 128,
    mimeType: mimeType,
    path: '/tmp/$name',
    status: UploadStatus.uploaded,
  );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this._handler);

  final Map<String, dynamic> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
