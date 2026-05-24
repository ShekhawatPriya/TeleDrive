import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/telegram/telegram_client_exceptions.dart';
import '../../../core/telegram/telegram_media_access_service.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_initializing) return;
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
          autoPlay: false,
          looping: false,
        );
      });
    } catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      _initializing = false;
    }
  }

  Future<VideoPlayerController?> _resolveController() async {
    final url = widget.url ?? widget.file?.streamUrl;
    if (url != null) {
      return VideoPlayerController.networkUrl(Uri.parse(url));
    }
    final file = widget.file;
    if (file == null || file.storageMode != 'client_managed') {
      if (mounted) setState(() => _error = 'No stream URL.');
      return null;
    }
    try {
      final local = await ref
          .read(telegramMediaAccessServiceProvider)
          .downloadForPrivateView(file, variant: 'original');
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

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
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
