import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_source_resolver.dart';
import '../../../models/drive_models.dart';

class VideoPreview extends ConsumerStatefulWidget {
  const VideoPreview({this.url, this.file, super.key})
    : assert(
        url != null || file != null,
        'VideoPreview needs either a url or a DriveFile.',
      );

  final String? url;
  final DriveFile? file;

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  Object? _error;
  bool _initializing = false;
  String? _sourceKey;
  final Set<String> _failedUrls = {};

  @override
  void initState() {
    super.initState();
    _sourceKey = _sourceKeyFor();
    _init();
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _sourceKeyFor();
    if (_sourceKey == nextKey) return;
    _sourceKey = nextKey;
    _failedUrls.clear();
    _error = null;
    _disposeControllers();
    _init();
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
            _debug('Video URL failed: ${resolved.url}', err);
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
            autoPlay: false,
            looping: false,
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
    final file = widget.file;
    final urls = file == null
        ? <String>[if (widget.url != null) widget.url!]
        : MediaSourceResolver.videoUrls(file, widget.url);
    String? url;
    for (final item in urls) {
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
    if (file == null || !MediaSourceResolver.canDownloadVideoOriginal(file)) {
      if (mounted) setState(() => _error = 'No stream URL.');
      return null;
    }
    final local = await MediaSourceResolver.downloadTelegramVariant(
      ref,
      file,
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

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewie?.dispose();
    _video?.dispose();
    _chewie = null;
    _video = null;
  }

  String _sourceKeyFor() {
    final file = widget.file;
    return '${widget.url}|${file?.id}|${file?.streamUrl}|'
        '${file?.originalRefAvailable}|${file?.uploadStatus}';
  }

  void _debug(String message, Object err) {
    if (!kDebugMode) return;
    debugPrint('$message: $err');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Center(child: Icon(Icons.video_file_outlined, size: 48));
    }
    final c = _chewie;
    if (c == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Chewie(controller: c);
  }
}
