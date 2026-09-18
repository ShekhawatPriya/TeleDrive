import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/media/media_source_resolver.dart';
import '../../../core/storage/thumbnail_cache_manager.dart';
import '../../../models/drive_models.dart';
import '../../profile/cache_controller.dart';

class PhotoViewerImage extends ConsumerStatefulWidget {
  const PhotoViewerImage({
    required this.file,
    required this.onTap,
    this.onDimensions,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onTap;
  final ValueChanged<Size>? onDimensions;

  @override
  ConsumerState<PhotoViewerImage> createState() => _PhotoViewerImageState();
}

class _PhotoViewerImageState extends ConsumerState<PhotoViewerImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ImageProvider? _currentImageProvider;
  String? _currentImageUrl;
  bool _hasRefreshed = false;

  Future<File?>? _localFuture;
  String? _localKey;
  String? _sourceKey;
  final Set<String> _failedUrls = {};

  @override
  void initState() {
    super.initState();
    _sourceKey = _sourceKeyFor(widget.file);
    _setupImageListener();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _sourceKeyFor(widget.file);
    if (_sourceKey != nextKey) {
      _sourceKey = nextKey;
      _hasRefreshed = false;
      _localKey = null;
      _localFuture = null;
      _failedUrls.clear();
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

    final urls = MediaSourceResolver.imageUrls(
      widget.file,
      MediaImageUse.fullImage,
    ).where((url) => !_failedUrls.contains(url)).toList();
    final url = urls.isEmpty ? null : urls.first;
    if (url == null) return;

    final imageProvider = MediaSourceResolver.isLocalPath(url)
        ? FileImage(File(url)) as ImageProvider
        : CachedNetworkImageProvider(
            url,
            cacheManager: TeleDriveThumbnailCacheManager.instance,
          );

    _attachProvider(imageProvider);
    _currentImageUrl = url;
  }

  void _attachProvider(ImageProvider provider) {
    final sourceKey = _sourceKey;
    _cleanImageListener();
    _currentImageProvider = provider;
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted || _hasRefreshed) return;
        _hasRefreshed = true;
        final dimensions = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && sourceKey == _sourceKey)
            widget.onDimensions?.call(dimensions);
        });
        ref.read(cacheControllerProvider).refreshCacheStats();
      },
      onError: (Object exception, StackTrace? stackTrace) {
        _markUrlFailed('Image stream failed', widget.file, exception);
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
    _currentImageUrl = null;
  }

  Future<File?>? _ensureLocalFuture(DriveFile file) {
    if (file.uploadStatus != null && file.uploadStatus != 'available') {
      return null;
    }
    final variants = MediaSourceResolver.imageTelegramVariants(
      file,
      MediaImageUse.fullImage,
    );
    if (variants.isEmpty) return null;
    final key =
        '${file.id}:${variants.join(',')}:${file.previewVersion ?? 0}:'
        '${file.thumbnailVersion ?? 0}';
    if (_localKey != key) {
      _localKey = key;
      _localFuture = _downloadLocal(file);
    }
    return _localFuture;
  }

  Future<File?> _downloadLocal(DriveFile file) async {
    final local = await MediaSourceResolver.downloadFirstTelegramImage(
      ref,
      file,
      MediaImageUse.fullImage,
    );
    if (local != null && mounted) {
      _attachProvider(FileImage(local));
      setState(() {});
    }
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final urls = MediaSourceResolver.imageUrls(
      file,
      MediaImageUse.fullImage,
    ).where((url) => !_failedUrls.contains(url)).toList();
    final url = urls.isEmpty ? null : urls.first;

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
        (MediaSourceResolver.isLocalPath(url)
            ? FileImage(File(url)) as ImageProvider
            : CachedNetworkImageProvider(
                url,
                cacheManager: TeleDriveThumbnailCacheManager.instance,
              ));

    return _photoView(imageProvider, url: url);
  }

  Widget _photoView(ImageProvider imageProvider, {String? url}) {
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
      errorBuilder: (_, err, _) {
        if (url != null) return _urlError(url, err);
        _debug('Local photo decode failed', err);
        return _fallback(context);
      },
    );
  }

  Widget _urlError(String url, Object err) {
    _debug('Photo URL failed: $url', err);
    if (_failedUrls.add(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setupImageListener();
        setState(() {});
      });
    }
    return _fallback(context);
  }

  void _markUrlFailed(String message, DriveFile file, Object err) {
    final currentUrl = _currentImageUrl;
    if (currentUrl == null) return;
    _debug('$message: $currentUrl', err);
    if (_failedUrls.add(currentUrl)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setupImageListener();
        setState(() {});
      });
    }
  }

  String _sourceKeyFor(DriveFile file) =>
      '${file.id}|${file.previewUrl}|${file.thumbnailUrl}|'
      '${file.previewRefAvailable}|${file.thumbnailRefAvailable}|'
      '${file.originalRefAvailable}|${file.previewVersion}|'
      '${file.thumbnailVersion}|${file.uploadStatus}';

  void _debug(String message, Object err) {
    if (!kDebugMode) return;
    debugPrint('$message: $err');
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
