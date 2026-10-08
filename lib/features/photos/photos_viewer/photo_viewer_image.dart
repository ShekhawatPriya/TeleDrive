import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../core/media/photo_media_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/media/media_source_resolver.dart';
import '../../../core/storage/thumbnail_cache_manager.dart';
import '../../../models/drive_models.dart';

class PhotoViewerImage extends ConsumerStatefulWidget {
  const PhotoViewerImage({
    required this.file,
    required this.onTap,
    this.onDimensions,
    this.onZoomChanged,
    this.active = false,
    super.key,
  });

  final DriveFile file;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<Size>? onDimensions;
  final ValueChanged<bool>? onZoomChanged;

  @override
  ConsumerState<PhotoViewerImage> createState() => _PhotoViewerImageState();
}

class _PhotoViewerImageState extends ConsumerState<PhotoViewerImage> {
  final _zoomController = PhotoViewController();
  CancelToken? _originalCancel, _localCancel;
  Timer? _originalDelay;
  ImageProvider? _originalProvider;
  String? _originalError;
  double? _upgradeRelativeScale;
  Offset? _upgradePosition;

  void _prepareOriginal() {
    if (!widget.active ||
        _originalProvider != null ||
        _originalError != null ||
        _originalCancel != null ||
        !(widget.file.originalRefAvailable || widget.file.isClientManaged))
      return;
    _originalDelay?.cancel();
    _originalDelay = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted || !widget.active) return;
      final sourceKey = _sourceKey;
      final token = CancelToken();
      _originalCancel = token;
      try {
        final original = await ref
            .read(photoMediaLoaderProvider)
            .original(widget.file, token);
        if (!mounted ||
            token.isCancelled ||
            sourceKey != _sourceKey ||
            !widget.active)
          return;
        final viewport = _viewport, size = _decodedSize;
        if (viewport != null && size != null && _zoomController.scale != null) {
          _upgradeRelativeScale =
              _zoomController.scale! /
              math.min(
                viewport.width / size.width,
                viewport.height / size.height,
              );
          _upgradePosition = _zoomController.position;
        }
        final provider = ResizeImage(
          FileImage(original),
          width: 4096,
          height: 4096,
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        );
        _attachProvider(provider);
        setState(() {
          _originalProvider = provider;
          _originalError = null;
        });
      } catch (_) {
        if (mounted && !token.isCancelled && sourceKey == _sourceKey)
          setState(() => _originalError = 'Full resolution unavailable');
      } finally {
        if (identical(_originalCancel, token)) _originalCancel = null;
      }
    });
  }

  StreamSubscription<PhotoViewControllerValue>? _zoomSubscription;
  Size? _decodedSize;
  Size? _viewport;
  bool? _zoomed;

  void _reportZoom() {
    final image = _decodedSize;
    final viewport = _viewport;
    final scale = _zoomController.scale;
    if (image == null || viewport == null || scale == null) return;
    final contained = math.min(
      viewport.width / image.width,
      viewport.height / image.height,
    );
    final zoomed = scale > contained * 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ImageProvider? _currentImageProvider;
  String? _currentImageUrl;

  Future<File?>? _localFuture;
  String? _localKey;
  String? _sourceKey;
  final Set<String> _failedUrls = {};

  @override
  void initState() {
    super.initState();
    _zoomSubscription = _zoomController.outputStateStream.listen(
      (_) => _reportZoom(),
    );
    _sourceKey = _sourceKeyFor(widget.file);
    _setupImageListener();
    _prepareOriginal();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _sourceKeyFor(widget.file);
    if (_sourceKey != nextKey) {
      _originalCancel?.cancel();
      _originalCancel = null;
      _originalDelay?.cancel();
      _originalProvider = null;
      _originalError = null;
      _localCancel?.cancel();
      _sourceKey = nextKey;
      _decodedSize = null;
      _localKey = null;
      _localFuture = null;
      _failedUrls.clear();
      _setupImageListener();
    }
    if (!widget.active) {
      _originalDelay?.cancel();
      _originalCancel?.cancel();
      _originalCancel = null;
      _localCancel?.cancel();
      _localKey = null;
      _localFuture = null;
    } else if (!oldWidget.active || _sourceKeyFor(oldWidget.file) != nextKey) {
      _prepareOriginal();
    }
  }

  @override
  void dispose() {
    _originalDelay?.cancel();
    _originalCancel?.cancel();
    _localCancel?.cancel();
    _zoomSubscription?.cancel();
    _zoomController.dispose();
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
        if (!mounted || sourceKey != _sourceKey) return;
        final dimensions = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        _decodedSize = dimensions;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && sourceKey == _sourceKey) {
            widget.onDimensions?.call(dimensions);
            final relative = _upgradeRelativeScale, viewport = _viewport;
            if (relative != null && viewport != null) {
              _upgradeRelativeScale = null;
              _zoomController.scale =
                  relative *
                  math.min(
                    viewport.width / dimensions.width,
                    viewport.height / dimensions.height,
                  );
              _zoomController.position = _upgradePosition ?? Offset.zero;
            }
            _reportZoom();
          }
        });
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
    ).where((variant) => variant != 'original').toList();
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
    final sourceKey = _sourceKey;
    final cancel = CancelToken();
    _localCancel = cancel;
    final local = await MediaSourceResolver.downloadFirstTelegramImage(
      ref,
      file,
      MediaImageUse.fullImage,
      cancelToken: cancel,
      allowOriginal: false,
    );
    if (local != null &&
        mounted &&
        !cancel.isCancelled &&
        _originalProvider == null &&
        sourceKey == _sourceKey) {
      _attachProvider(FileImage(local));
      setState(() {});
    }
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    if (_originalProvider != null) return _photoView(_originalProvider!);
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
      if (widget.active &&
          _originalError == null &&
          (file.originalRefAvailable || file.isClientManaged)) {
        return const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator.adaptive(
              semanticsLabel: 'Preparing photo',
            ),
          ),
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
    return LayoutBuilder(
      builder: (context, bounds) {
        _viewport = bounds.biggest;
        return PhotoView(
          controller: _zoomController,
          imageProvider: imageProvider,

          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          initialScale: PhotoViewComputedScale.contained,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          gaplessPlayback: true,
          onTapUp: (_, __, ___) => widget.onTap(),
          loadingBuilder: (_, __) => const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
          errorBuilder: (_, err, _) {
            if (url != null) return _urlError(url, err);
            _debug('Local photo decode failed', err);
            if (identical(imageProvider, _originalProvider)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !identical(imageProvider, _originalProvider))
                  return;
                setState(() {
                  _originalProvider = null;
                  _originalError = 'Full resolution unavailable';
                  _setupImageListener();
                });
              });
              return const SizedBox.shrink();
            }
            return _fallback(context);
          },
        );
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
      '${file.thumbnailVersion}|${file.uploadStatus}|${file.modifiedAt}|${file.size}';

  void _debug(String message, Object err) {
    if (!kDebugMode) return;
    debugPrint('$message: $err');
  }

  Widget _fallback(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          _originalError ?? 'Could not load this photo.',
          style: const TextStyle(color: Colors.white),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _failedUrls.clear();
              _localKey = null;
              _localFuture = null;
              _originalProvider = null;
              _setupImageListener();
            });
            _prepareOriginal();
          },
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}
