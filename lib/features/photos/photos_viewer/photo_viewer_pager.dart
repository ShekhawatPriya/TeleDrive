import 'package:flutter/material.dart';

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
    super.key,
  });

  final List<DriveFile> files;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapMedia;

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
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
            file: file,
            isActive: i == _index,
            onTap: widget.onTapMedia,
          );
        }
        return PhotoViewerImage(file: file, onTap: widget.onTapMedia);
      },
    );
  }
}
