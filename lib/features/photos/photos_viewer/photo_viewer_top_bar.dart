import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/adaptive_surface.dart';

/// A floating toolbar with stable contrast over photos in either app theme.
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
    final theme = Theme.of(context);
    return AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.short3,
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Theme(
              data: theme.copyWith(
                colorScheme: AppBrand.scheme(Brightness.dark),
              ),
              child: AdaptiveSurface(
                radius: 28,
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: onBack,
                          tooltip: 'Back',
                          icon: Icon(
                            theme.platform == TargetPlatform.iOS
                                ? Icons.chevron_left_rounded
                                : Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: file == null ? null : onStar,
                          tooltip: file?.starred == true
                              ? 'Remove star'
                              : 'Add star',
                          icon: Icon(
                            file?.starred == true
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: file == null ? null : onDownload,
                          tooltip: 'Download',
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: file == null ? null : onInfo,
                          tooltip: 'Info',
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: file == null ? null : onMore,
                          tooltip: 'More',
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
