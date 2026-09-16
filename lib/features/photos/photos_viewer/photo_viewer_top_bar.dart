import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/native_glass_button.dart';

/// Navigation stays above the image; photo actions live at the bottom edge.
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
  final VoidCallback onBack, onStar, onInfo, onDownload, onMore;

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(file?.createdAt ?? '')?.toLocal();
    return AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Row(
                  children: [
                    NativeGlassButton(
                      label: 'Back',
                      symbol: 'chevron.left',
                      icon: CupertinoIcons.chevron_back,
                      onPressed: onBack,
                      white: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            created == null
                                ? 'Photo'
                                : DateFormat.yMMMMd().format(created),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (created != null)
                            Text(
                              DateFormat.jm().format(created),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    NativeGlassButton(
                      label: 'More',
                      symbol: 'ellipsis',
                      icon: CupertinoIcons.ellipsis,
                      onPressed: file == null ? null : onMore,
                      white: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhotoViewerActions extends StatelessWidget {
  const PhotoViewerActions({
    super.key,
    required this.file,
    required this.onStar,
    required this.onInfo,
    required this.onDownload,
  });
  final DriveFile file;
  final VoidCallback onStar, onInfo, onDownload;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      NativeGlassButton(
        label: 'Download',
        symbol: 'square.and.arrow.down',
        icon: CupertinoIcons.square_arrow_down,
        onPressed: onDownload,
        white: true,
      ),
      NativeGlassButton(
        label: file.starred ? 'Remove star' : 'Add star',
        symbol: file.starred ? 'star.fill' : 'star',
        icon: file.starred ? CupertinoIcons.star_fill : CupertinoIcons.star,
        onPressed: onStar,
        white: true,
      ),
      NativeGlassButton(
        label: 'Info',
        symbol: 'info.circle',
        icon: CupertinoIcons.info_circle,
        onPressed: onInfo,
        white: true,
      ),
    ],
  );
}
