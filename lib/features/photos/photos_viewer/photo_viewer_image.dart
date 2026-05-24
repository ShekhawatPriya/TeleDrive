import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/storage/thumbnail_cache_manager.dart';
import '../../../core/telegram/telegram_client_exceptions.dart';
import '../../../core/telegram/telegram_media_access_service.dart';
import '../../../models/drive_models.dart';
import '../../profile/cache_controller.dart';

class PhotoViewerImage extends ConsumerStatefulWidget {
  const PhotoViewerImage({required this.file, required this.onTap, super.key});

  final DriveFile file;
  final VoidCallback onTap;

  @override
  ConsumerState<PhotoViewerImage> createState() => _PhotoViewerImageState();
}

class _PhotoViewerImageState extends ConsumerState<PhotoViewerImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ImageProvider? _currentImageProvider;
  bool _hasRefreshed = false;

  Future<File?>? _localFuture;
  String? _localKey;

  @override
  void initState() {
    super.initState();
    _setupImageListener();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id ||
        oldWidget.file.previewUrl != widget.file.previewUrl ||
        oldWidget.file.thumbnailUrl != widget.file.thumbnailUrl) {
      _hasRefreshed = false;
      _localKey = null;
      _localFuture = null;
      _setupImageListener();
    }
  }

  @override
  void dispose() {
    _cleanImageListener();
    super.dispose();
  }

  void _setupImageListener() {
    _cleanImageListener();

    final url = widget.file.previewUrl ?? widget.file.thumbnailUrl;
    if (url == null) return;

    final imageProvider = url.startsWith('/') || url.contains(':\\')
        ? FileImage(File(url)) as ImageProvider
        : CachedNetworkImageProvider(
            url,
            cacheManager: TeleDriveThumbnailCacheManager.instance,
          );

    _attachProvider(imageProvider);
  }

  void _attachProvider(ImageProvider provider) {
    _cleanImageListener();
    _currentImageProvider = provider;
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted || _hasRefreshed) return;
        _hasRefreshed = true;
        ref.read(cacheControllerProvider).refreshCacheStats();
      },
      onError: (Object exception, StackTrace? stackTrace) {
        debugPrint('Error loading image in viewer: $exception');
      },
    );
    _imageStream!.addListener(_imageListener!);
  }

  void _cleanImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
    _currentImageProvider = null;
  }

  Future<File?>? _ensureLocalFuture(DriveFile file) {
    if (file.storageMode != 'client_managed' ||
        file.uploadStatus != 'available') {
      return null;
    }
    final variant = file.previewRefAvailable
        ? 'preview'
        : file.originalRefAvailable
        ? 'original'
        : null;
    if (variant == null) return null;
    final version = variant == 'preview' ? file.previewVersion : 0;
    final key = '${file.id}:$variant:${version ?? 0}';
    if (_localKey != key) {
      _localKey = key;
      _localFuture = _downloadLocal(file, variant);
    }
    return _localFuture;
  }

  Future<File?> _downloadLocal(DriveFile file, String variant) async {
    try {
      final local = await ref
          .read(telegramMediaAccessServiceProvider)
          .downloadForPrivateView(file, variant: variant)
          .timeout(const Duration(seconds: 90));
      if (local != null && mounted) {
        _attachProvider(FileImage(local));
        setState(() {});
      }
      return local;
    } on TelegramClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final url = file.previewUrl ?? file.thumbnailUrl;

    if (url == null) {
      final localFuture = _ensureLocalFuture(file);
      if (localFuture != null) {
        return FutureBuilder<File?>(
          future: localFuture,
          builder: (context, snapshot) {
            final local = snapshot.data;
            if (local != null) {
              return _photoView(FileImage(local));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              );
            }
            return _fallback(context);
          },
        );
      }
      return _fallback(context);
    }

    final imageProvider =
        _currentImageProvider ??
        (url.startsWith('/') || url.contains(':\\')
            ? FileImage(File(url)) as ImageProvider
            : CachedNetworkImageProvider(
                url,
                cacheManager: TeleDriveThumbnailCacheManager.instance,
              ));

    return _photoView(imageProvider);
  }

  Widget _photoView(ImageProvider imageProvider) {
    return PhotoView(
      imageProvider: imageProvider,
      heroAttributes: PhotoViewHeroAttributes(tag: 'photo-${widget.file.id}'),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      onTapUp: (_, __, ___) => widget.onTap(),
      loadingBuilder: (_, __) => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
      errorBuilder: (_, __, ___) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 64,
        ),
      ),
    );
  }
}
