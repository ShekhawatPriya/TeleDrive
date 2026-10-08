import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import 'photo_viewer_image.dart';
import 'photo_viewer_video.dart';
import '../../../core/media/photo_playback.dart';

class PhotoViewerPager extends StatefulWidget {
  const PhotoViewerPager({
    required this.files,
    required this.initialIndex,
    required this.onPageChanged,
    required this.onTapMedia,
    this.onDimensions,
    this.onZoomChanged,
    this.active = true,
    this.onNativeDrag,
    this.onFullscreen,
    this.onNativeChanged,
    super.key,
  });

  final List<DriveFile> files;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final bool active;
  final ValueChanged<bool>? onFullscreen;
  final void Function(String id, bool native)? onNativeChanged;
  final void Function(String phase, Offset position, Offset velocity)?
  onNativeDrag;
  final VoidCallback onTapMedia;
  final void Function(String id, Size dimensions)? onDimensions;
  final void Function(String id, bool zoomed)? onZoomChanged;

  @override
  State<PhotoViewerPager> createState() => _PhotoViewerPagerState();
}

class _PhotoViewerPagerState extends State<PhotoViewerPager> {
  late final PageController _controller;
  late int _index;
  bool _scrolling = false;
  Drag? _nativePageDrag;
  void _dragPage(String phase, Offset position, Offset velocity) {
    if (!_controller.hasClients) return;
    switch (phase) {
      case 'start':
        _nativePageDrag?.cancel();
        _nativePageDrag = _controller.position.drag(
          DragStartDetails(globalPosition: position),
          () => _nativePageDrag = null,
        );
      case 'update':
        _nativePageDrag?.update(
          DragUpdateDetails(
            globalPosition: position,
            delta: Offset(velocity.dx, 0),
            primaryDelta: velocity.dx,
          ),
        );
      case 'end':
        _nativePageDrag?.end(
          DragEndDetails(
            velocity: Velocity(pixelsPerSecond: Offset(velocity.dx, 0)),
            primaryVelocity: velocity.dx,
          ),
        );
        _nativePageDrag = null;
      default:
        _nativePageDrag?.cancel();
        _nativePageDrag = null;
    }
  }

  final Map<String, PhotoPlaybackMemory> _playback = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant PhotoViewerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.removeWhere((id, _) => !widget.files.any((f) => f.id == id));
    if (widget.initialIndex != _index) {
      _index = widget.initialIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _nativePageDrag?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoViewGestureDetectorScope(
      axis: Axis.horizontal,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth != 0 || n.metrics.axis != Axis.horizontal) return false;
          if (n is ScrollStartNotification && !_scrolling)
            setState(() => _scrolling = true);
          if (n is ScrollEndNotification && _scrolling)
            setState(() => _scrolling = false);
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.files.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            widget.onPageChanged(i);
          },
          itemBuilder: (context, i) {
            final file = widget.files[i];
            if (isVideoFile(file)) {
              return PhotoViewerVideo(
                key: ValueKey(file.id),
                file: file,
                isActive: widget.active && !_scrolling && i == _index,
                memory: _playback.putIfAbsent(file.id, PhotoPlaybackMemory.new),
                onDimensions: (size) =>
                    widget.onDimensions?.call(file.id, size),
                onNativeDrag: widget.onNativeDrag,
                onNativePageDrag: _dragPage,
                onFullscreen: widget.onFullscreen,
                onNativeChanged: (value) =>
                    widget.onNativeChanged?.call(file.id, value),
                onNativePage: (forward) {
                  if (!_controller.hasClients) return;
                  final next = (_index + (forward ? 1 : -1)).clamp(
                    0,
                    widget.files.length - 1,
                  );
                  _controller.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                onTap: widget.onTapMedia,
              );
            }
            return PhotoViewerImage(
              key: ValueKey(file.id),
              file: file,
              onTap: widget.onTapMedia,
              active: widget.active && !_scrolling && i == _index,
              onZoomChanged: (zoomed) =>
                  widget.onZoomChanged?.call(file.id, zoomed),
              onDimensions: (size) => widget.onDimensions?.call(file.id, size),
            );
          },
        ),
      ),
    );
  }
}
