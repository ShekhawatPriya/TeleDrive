import 'package:flutter/material.dart';

import '../../../models/drive_models.dart';

class PhotoViewerTopBar extends StatelessWidget {
  const PhotoViewerTopBar({
    required this.file,
    required this.visible,
    required this.onBack,
    required this.onStar,
    required this.onInfo,
    required this.onDownload,
    required this.onMore,
    super.key,
  });

  final DriveFile? file;
  final bool visible;
  final VoidCallback onBack;
  final VoidCallback onStar;
  final VoidCallback onInfo;
  final VoidCallback onDownload;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back',
                ),
                const Spacer(),
                IconButton(
                  onPressed: file == null ? null : onStar,
                  icon: Icon(
                    file?.starred == true ? Icons.star : Icons.star_border,
                    color: Colors.white,
                  ),
                  tooltip: 'Star',
                ),
                IconButton(
                  onPressed: file == null ? null : onDownload,
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Download',
                ),
                IconButton(
                  onPressed: file == null ? null : onInfo,
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  tooltip: 'Info',
                ),
                IconButton(
                  onPressed: file == null ? null : onMore,
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
