import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import 'photo_viewer_image.dart';
import 'photo_viewer_video.dart';

class PhotoViewerPager extends StatefulWidget {
  const PhotoViewerPager({
    required this.files,
    required this.initialIndex,
    required this.onPageChanged,
    required this.onTapMedia,
    this.onDimensions,
    super.key,
  });

  final List<DriveFile> files;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapMedia;
  final void Function(String id, Size dimensions)? onDimensions;

  @override
  State<PhotoViewerPager> createState() => _PhotoViewerPagerState();
}

class _PhotoViewerPagerState extends State<PhotoViewerPager> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant PhotoViewerPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != _index) {
      _index = widget.initialIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoViewGestureDetectorScope(
      axis: Axis.horizontal,
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
              isActive: i == _index,
              onTap: widget.onTapMedia,
            );
          }
          return PhotoViewerImage(
            key: ValueKey(file.id),
            file: file,
            onTap: widget.onTapMedia,
            onDimensions: (size) => widget.onDimensions?.call(file.id, size),
          );
        },
      ),
    );
  }
}
