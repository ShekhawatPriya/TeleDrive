import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/native_glass_button.dart';
import 'native_photo_controls.dart';
import '../../../widgets/ios_more_menu.dart';

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
    this.menuSections,
    super.key,
  });
  final DriveFile? file;
  final bool visible;
  final IosMenuSectionsBuilder? menuSections;
  final VoidCallback onBack, onStar, onInfo, onDownload, onMore;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
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
                    if (ios)
                      NativeGlassButton(
                        label: 'Back',
                        symbol: 'chevron.left',
                        icon: CupertinoIcons.chevron_back,
                        onPressed: onBack,
                        white: true,
                      )
                    else
                      IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                    if (Theme.of(context).platform == TargetPlatform.iOS &&
                        menuSections != null)
                      IosMoreButton(white: true, sectionsBuilder: menuSections!)
                    else if (!ios)
                      IconButton(
                        tooltip: 'More',
                        onPressed: file == null ? null : onMore,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      )
                    else
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
    this.onShare,
    this.onDelete,
    this.infoSelected = false,
  });
  final DriveFile file;
  final bool infoSelected;
  final VoidCallback onStar, onInfo, onDownload;
  final VoidCallback? onShare, onDelete;
  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    Widget action(
      String label,
      IconData icon,
      VoidCallback callback, {
      bool selected = false,
    }) => Semantics(
      selected: selected,
      child: IconButton(
        style:
            ios &&
                (label == 'Share' || label == 'Download' || label == 'Delete')
            ? IconButton.styleFrom(backgroundColor: const Color(0xFF252529))
            : null,
        tooltip: label,
        onPressed: callback,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: Colors.white, size: ios ? 22 : 24),
      ),
    );
    final share = action(
      onShare == null ? 'Download' : 'Share',
      ios
          ? (onShare == null
                ? CupertinoIcons.square_arrow_down
                : CupertinoIcons.share)
          : (onShare == null ? Icons.download_outlined : Icons.share_outlined),
      onShare ?? onDownload,
    );
    final star = action(
      file.starred ? 'Remove star' : 'Add star',
      file.starred
          ? (ios ? CupertinoIcons.star_fill : Icons.star)
          : (ios ? CupertinoIcons.star : Icons.star_border),
      onStar,
      selected: file.starred,
    );
    final info = action(
      'Info',
      infoSelected
          ? (ios ? CupertinoIcons.info_circle_fill : Icons.info)
          : (ios ? CupertinoIcons.info_circle : Icons.info_outline),
      onInfo,
      selected: infoSelected,
    );
    final fallback = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        share,
        if (ios)
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF252529),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [star, info],
              ),
            ),
          )
        else ...[
          star,
          info,
        ],
        if (onDelete != null)
          action(
            'Delete',
            ios ? CupertinoIcons.trash : Icons.delete_outline,
            onDelete!,
          )
        else
          const SizedBox(width: 48),
      ],
    );
    if (!ios) return fallback;
    return NativePhotoControls(
      starred: file.starred,
      infoSelected: infoSelected,
      onStar: onStar,
      onInfo: onInfo,
      onShare: onShare ?? onDownload,
      onDelete: onDelete,
      download: onShare == null,
      fallback: fallback,
    );
  }
}
