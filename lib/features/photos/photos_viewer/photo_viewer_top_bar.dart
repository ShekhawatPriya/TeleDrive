import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/native_glass_button.dart';
import 'native_photo_controls.dart';
import '../../../core/theme/ios_palette.dart';
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
        tooltip: label,
        onPressed: callback,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: Colors.white, size: 24),
      ),
    );
    final share = ios
        ? NativeGlassButton(
            label: onShare == null ? 'Download' : 'Share',
            symbol: onShare == null
                ? 'square.and.arrow.down'
                : 'square.and.arrow.up',
            icon: onShare == null
                ? CupertinoIcons.square_arrow_down
                : CupertinoIcons.share,
            onPressed: onShare ?? onDownload,
            white: true,
            symbolSize: 24,
          )
        : action(
            onShare == null ? 'Download' : 'Share',
            onShare == null ? Icons.download_outlined : Icons.share_outlined,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        share,
        if (ios)
          Theme(
            data: Theme.of(context).copyWith(
              brightness: Brightness.dark,
              colorScheme: iosPalette(
                ColorScheme.fromSeed(
                  seedColor: Theme.of(context).colorScheme.primary,
                  brightness: Brightness.dark,
                ),
              ),
            ),
            child: NativePhotoControls(
              starred: file.starred,
              infoSelected: infoSelected,
              onStar: onStar,
              onInfo: onInfo,
              fallback: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE6252529),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [star, info],
                  ),
                ),
              ),
            ),
          )
        else ...[
          star,
          info,
        ],
        if (onDelete != null)
          if (ios)
            NativeGlassButton(
              label: 'Delete',
              symbol: 'trash',
              icon: CupertinoIcons.trash,
              onPressed: onDelete,
              white: true,
              symbolSize: 24,
            )
          else
            action('Delete', Icons.delete_outline, onDelete!)
        else
          const SizedBox(width: 48),
      ],
    );
  }
}
