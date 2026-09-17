import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../models/drive_models.dart';
import '../config/app_config.dart';
import '../storage/thumbnail_cache_manager.dart';
import '../telegram/telegram_media_access_service.dart';
import '../utils/stable_hash.dart';
import 'client_derivative_generator.dart';
import 'media_source_resolver.dart';
import 'thumbnail_scheduler.dart';

final thumbnailSchedulerProvider = Provider<ThumbnailScheduler<File>>((ref) {
  final scheduler = ThumbnailScheduler<File>();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

final thumbnailLoaderProvider = Provider<ThumbnailLoader>((ref) {
  final identity = ref.watch(
    authControllerProvider.select((auth) {
      final telegram = auth.user?.telegramId;
      return (
        auth.user?.userId ?? auth.activeAccount?.userId,
        telegram != null && telegram != 0
            ? telegram
            : auth.activeAccount?.telegramId,
        auth.token,
      );
    }),
  );
  final loader = ThumbnailLoader(
    scope: '${AppConfig.storageNamespace}:${identity.$1}:${identity.$2}',
    cache: TeleDriveThumbnailCacheManager.instance,
    telegram: (file, variant, token) => ref
        .read(telegramMediaAccessServiceProvider)
        .downloadForPrivateView(
          file,
          variant: variant,
          timeout: Duration(seconds: variant == 'original' ? 30 : 15),
          cancelToken: token,
        ),
  );
  ref.onDispose(loader.dispose);
  return loader;
});

typedef ThumbnailTelegramDownload =
    Future<File?> Function(DriveFile file, String variant, CancelToken token);

/// Disk lookup precedes authorization, media-ref resolution, and network work.
/// Successful files alone are cached; transient errors never become cache hits.
class ThumbnailLoader {
  ThumbnailLoader({
    required this.scope,
    required this.cache,
    required this.telegram,
    Dio? http,
  }) : _http =
           http ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           );

  final String scope;
  final BaseCacheManager cache;
  final ThumbnailTelegramDownload telegram;
  final Dio _http;
  final _memory = <String, File>{};
  bool _disposed = false;

  String keyFor(DriveFile file) =>
      'thumb-v2-${stableHash('$scope:${file.id}:${file.modifiedAt}:${file.size}:'
      '${file.thumbnailVersion}:${file.previewVersion}:'
      '${file.thumbnailRefAvailable}:${file.previewRefAvailable}:'
      '${file.originalRefAvailable}:${file.uploadStatus}:'
      '${_stableUrl(file.thumbnailUrl)}:${_stableUrl(file.previewUrl)}')}';

  static String? _stableUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;
    final query = Map<String, String>.from(uri.queryParameters)
      ..removeWhere(
        (key, _) => const {
          'token',
          'access_token',
          'signature',
          'expires',
        }.contains(key),
      );
    return uri.replace(queryParameters: query).toString();
  }

  bool hasSources(DriveFile file) =>
      MediaSourceResolver.imageUrls(file, MediaImageUse.thumbnail).isNotEmpty ||
      MediaSourceResolver.imageTelegramVariants(
        file,
        MediaImageUse.thumbnail,
      ).isNotEmpty;

  bool canUseOriginal(DriveFile file) =>
      file.kind == FileKind.image && file.originalRefAvailable;

  Future<File?> cached(DriveFile file) async {
    final key = keyFor(file);
    final memory = _memory.remove(key);
    if (memory != null && await memory.exists()) {
      _memory[key] = memory;
      return memory;
    }
    final entry = await cache.getFileFromCache(key);
    if (entry == null || !await entry.file.exists()) return null;
    _remember(key, entry.file);
    return entry.file;
  }

  Future<File?> load(
    DriveFile file,
    CancelToken token, {
    bool original = false,
  }) async {
    _check(token);
    final hit = await cached(file);
    _check(token);
    if (hit != null) return hit;
    final key = keyFor(file);
    if (original) {
      if (!canUseOriginal(file)) return null;
      final source = await telegram(file, 'original', token);
      _check(token);
      if (source == null) return null;
      // A HEIC original is not a portable grid image. Generate one bounded
      // derivative through the existing native media bridge and retain it.
      final derivatives = await const ClientDerivativeGenerator().generate(
        localId: key,
        originalPath: source.path,
        originalFilename: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
        requiresThumbnail: true,
        requiresPreview: false,
      );
      final thumbnail = derivatives.thumbnail;
      if (thumbnail == null) return null;
      try {
        _check(token);
        return await _store(
          key,
          await File(thumbnail.path).readAsBytes(),
          token,
        );
      } finally {
        final generated = File(thumbnail.path);
        if (await generated.exists()) await generated.delete();
      }
    }
    for (final url in MediaSourceResolver.imageUrls(
      file,
      MediaImageUse.thumbnail,
    )) {
      _check(token);
      try {
        final Uint8List bytes;
        if (MediaSourceResolver.isLocalPath(url)) {
          bytes = await File(url).readAsBytes();
        } else {
          final response = await _http.get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
            cancelToken: token,
          );
          bytes = Uint8List.fromList(response.data!);
        }
        return await _store(key, bytes, token);
      } catch (_) {
        _check(token);
      }
    }
    if (file.uploadStatus != null && file.uploadStatus != 'available')
      return null;
    for (final variant in MediaSourceResolver.imageTelegramVariants(
      file,
      MediaImageUse.thumbnail,
    ).where((variant) => variant != 'original')) {
      _check(token);
      try {
        final source = await telegram(file, variant, token);
        _check(token);
        if (source != null) {
          return await _store(key, await source.readAsBytes(), token);
        }
      } catch (_) {
        _check(token);
      }
    }
    return null;
  }

  Future<File> _store(String key, Uint8List bytes, CancelToken token) async {
    _check(token);
    // Reject corrupt/unsupported data before marking a source successful, so
    // decode failure advances to the next source instead of sticking forever.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    _check(token);
    final file = await cache.putFile(
      key,
      bytes,
      key: key,
      fileExtension: 'img',
      maxAge: const Duration(days: 30),
    );
    _check(token);
    _remember(key, file);
    return file;
  }

  void _remember(String key, File file) {
    _memory.remove(key);
    _memory[key] = file;
    while (_memory.length > 256) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<void> evict(DriveFile file) async {
    final key = keyFor(file);
    _memory.remove(key);
    await cache.removeFile(key);
  }

  void _check(CancelToken token) {
    if (token.isCancelled) throw token.cancelError!;
    if (_disposed) throw StateError('Thumbnail account changed');
  }

  void dispose() {
    _disposed = true;
    _memory.clear();
    _http.close(force: true);
  }
}
