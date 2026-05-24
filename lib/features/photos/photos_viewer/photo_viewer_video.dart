import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/telegram/telegram_client_exceptions.dart';
import '../../../core/telegram/telegram_media_access_service.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _init();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _initializing = true;
    try {
      final controller = await _resolveController();
      if (controller == null) return;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _video = controller;
        _chewie = ChewieController(
          videoPlayerController: controller,
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
    } catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      _initializing = false;
    }
  }

  Future<VideoPlayerController?> _resolveController() async {
    final url = widget.file.streamUrl;
    if (url != null) {
      return VideoPlayerController.networkUrl(Uri.parse(url));
    }
    if (widget.file.storageMode != 'client_managed') {
      if (mounted) setState(() => _error = 'No stream URL.');
      return null;
    }
    try {
      final local = await ref
          .read(telegramMediaAccessServiceProvider)
          .downloadForPrivateView(widget.file, variant: 'original');
      if (local == null) {
        if (mounted) setState(() => _error = 'Video unavailable.');
        return null;
      }
      return VideoPlayerController.file(File(local.path));
    } on TelegramClientException catch (err) {
      if (mounted) setState(() => _error = err.message);
      return null;
    }
  }

  void _disposeControllers() {
    _chewie?.dispose();
    _video?.dispose();
    _chewie = null;
    _video = null;
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
