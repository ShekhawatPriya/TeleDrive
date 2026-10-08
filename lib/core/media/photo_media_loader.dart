import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../storage/download_cache.dart';
import '../telegram/telegram_media_access_service.dart';
import '../../features/auth/auth_controller.dart';
import '../../models/drive_models.dart';
import 'media_source_resolver.dart';

final photoMediaLoaderProvider = Provider<PhotoMediaLoader>(
  (ref) => PhotoMediaLoader(
    ref.watch(telegramMediaAccessServiceProvider),
    ref.watch(authControllerProvider.notifier),
  ),
);

class PhotoMediaLoader {
  PhotoMediaLoader(
    this._media,
    this._auth, {
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getTemporaryDirectory;
  final Future<Directory> Function() _directory;
  final TelegramMediaAccessService _media;
  final AuthController _auth;
  String revision(DriveFile file) =>
      '${AppConfig.storageNamespace}:${_auth.user?.userId}:${_auth.user?.telegramId}:'
      '${file.id}:${file.modifiedAt}:${file.size}:${file.previewVersion}:${file.thumbnailVersion}';
  String get _namespace =>
      '${AppConfig.storageNamespace}:${_auth.user?.telegramId}';
  void _check(int generation, CancelToken token) {
    if (token.isCancelled) throw token.cancelError!;
    if (generation != _media.generation || _auth.switchingAccount)
      throw StateError('The active account changed.');
  }

  Future<File?> cachedOriginal(DriveFile file, CancelToken token) async {
    final generation = _media.generation;
    final userId = _auth.user?.userId;
    if (userId == null) return null;
    final namespace = _namespace;
    final root = await _directory();
    _check(generation, token);
    final path = DownloadCache(root).relativePath(namespace, userId, file);
    final cached = File('${root.path}/$path');
    final exists = await cached.exists();
    _check(generation, token);
    if (!exists) return null;
    final length = await cached.length();
    _check(generation, token);
    return length > 0 && (file.size <= 0 || length == file.size)
        ? cached
        : null;
  }

  Future<File> original(
    DriveFile file,
    CancelToken token, {
    ProgressCallback? progress,
  }) async {
    final generation = _media.generation;
    final userId = _auth.user?.userId;
    final namespace = _namespace;
    _check(generation, token);
    if (userId == null) throw StateError('Sign in to view this file.');
    final root = await _directory();
    _check(generation, token);
    final result = await DownloadCache(root).obtain(
      backend: namespace,
      userId: userId,
      file: file,
      download: (target) async {
        final local = await _media.downloadForPrivateView(
          file,
          variant: 'original',
          timeout: MediaSourceResolver.timeoutForVariant('original'),
          cancelToken: token,
          onProgress: progress,
        );
        _check(generation, token);
        if (local == null) throw StateError('The original is unavailable.');
        await local.copy(target);
        _check(generation, token);
      },
    );
    _check(generation, token);
    return result;
  }

  Future<String> video(
    DriveFile file,
    CancelToken token, {
    ProgressCallback? progress,
  }) async {
    // Local paths also support isolated device fixtures and optimistic files.
    final stream = file.streamUrl;
    if (stream != null && MediaSourceResolver.isLocalPath(stream))
      return stream;
    final cached = await cachedOriginal(file, token);
    if (cached != null) return cached.path;
    if (MediaSourceResolver.canDownloadVideoOriginal(file)) {
      return (await original(file, token, progress: progress)).path;
    }
    // Legacy, explicitly supplied stream URLs only. A failed direct transfer
    // never enters this branch or introduces a backend byte fallback.
    if (stream != null && stream.isNotEmpty) return stream;
    throw StateError('This video is not available yet.');
  }
}
