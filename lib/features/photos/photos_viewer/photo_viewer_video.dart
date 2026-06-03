import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_source_resolver.dart';
import '../../../models/drive_models.dart';

class PhotoViewerVideo extends ConsumerStatefulWidget {
  const PhotoViewerVideo({
    required this.file,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final DriveFile file;
  final bool isActive;
  final VoidCallback onTap;

  @override
  ConsumerState<PhotoViewerVideo> createState() => _PhotoViewerVideoState();
}

class _PhotoViewerVideoState extends ConsumerState<PhotoViewerVideo> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  Object? _error;
  bool _initializing = false;
  String? _sourceKey;
  final Set<String> _failedUrls = {};

  @override
  void initState() {
    super.initState();
    _sourceKey = _sourceKeyFor(widget.file);
    if (widget.isActive) _init();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _sourceKeyFor(widget.file);
    if (_sourceKey != nextKey) {
      _sourceKey = nextKey;
      _failedUrls.clear();
      _error = null;
      _disposeControllers();
      if (widget.isActive) _init();
      return;
    }
    if (widget.isActive && _video == null && _error == null && !_initializing) {
      _init();
    } else if (!widget.isActive && _video != null) {
      _disposeControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _init() async {
    if (_initializing) return;
    _initializing = true;
    try {
      while (mounted) {
        final resolved = await _resolveController();
        if (resolved == null) return;
        try {
          await resolved.controller.initialize();
        } catch (err) {
          await resolved.controller.dispose();
          if (resolved.url != null) {
            _debug('Photo video URL failed: ${resolved.url}', err);
            _failedUrls.add(resolved.url!);
            continue;
          }
          if (mounted) setState(() => _error = err);
          return;
        }
        if (!mounted) {
          await resolved.controller.dispose();
          return;
        }
        setState(() {
          _video = resolved.controller;
          _chewie = ChewieController(
            videoPlayerController: resolved.controller,
            autoPlay: true,
            looping: false,
            allowFullScreen: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.white,
              handleColor: Colors.white,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          );
        });
        return;
      }
    } catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      _initializing = false;
    }
  }

  Future<({VideoPlayerController controller, String? url})?>
  _resolveController() async {
    String? url;
    for (final item in MediaSourceResolver.videoUrls(widget.file, null)) {
      if (_failedUrls.contains(item)) continue;
      url = item;
      break;
    }
    if (url != null) {
      return (
        controller: VideoPlayerController.networkUrl(Uri.parse(url)),
        url: url,
      );
    }
    if (!MediaSourceResolver.canDownloadVideoOriginal(widget.file)) {
      if (mounted) setState(() => _error = 'No stream URL.');
      return null;
    }
    final local = await MediaSourceResolver.downloadTelegramVariant(
      ref,
      widget.file,
      'original',
    );
    if (local == null) {
      if (mounted) setState(() => _error = 'Video unavailable.');
      return null;
    }
    return (
      controller: VideoPlayerController.file(File(local.path)),
      url: null,
    );
  }

  void _disposeControllers() {
    _chewie?.dispose();
    _video?.dispose();
    _chewie = null;
    _video = null;
  }

  String _sourceKeyFor(DriveFile file) =>
      '${file.id}|${file.streamUrl}|${file.originalRefAvailable}|'
      '${file.uploadStatus}';

  void _debug(String message, Object err) {
    if (!kDebugMode) return;
    debugPrint('$message: $err');
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewie;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: _error != null
              ? const Icon(Icons.error_outline, color: Colors.white54, size: 48)
              : chewie == null
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Hero(
                  tag: 'photo-${widget.file.id}',
                  child: Chewie(controller: chewie),
                ),
        ),
      ),
    );
  }
}
