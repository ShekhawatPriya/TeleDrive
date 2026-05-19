import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/drive_models.dart';

/// Translucent overlay top bar for the photo viewer. Surface uses the
/// theme's `inverseSurface` (black-on-light, white-on-dark) at 60% opacity
/// so the underlying photo remains visible while the bar is readable.
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
      duration: AppDurations.short3,
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
                    file?.starred == true
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Star',
                ),
                IconButton(
                  onPressed: file == null ? null : onDownload,
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
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
