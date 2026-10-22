import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/native_glass_button.dart';
import '../../../widgets/native_glass_surface.dart';
import 'native_photo_controls.dart';
import '../../../widgets/ios_more_menu.dart';
import '../../../widgets/item_status.dart';

/// The Photos title: "Today", "Yesterday" or the date (with the year only
/// when it is not this year), then the time. Drive has no capture date or
/// place, so this is the item's Drive date, never an invented location.
({String day, String time}) photoViewerTitle(
  DateTime created, {
  required DateTime now,
  bool use24HourFormat = false,
}) {
  final date = DateTime(created.year, created.month, created.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(date).inDays;
  final day = days == 0
      ? 'Today'
      : days == 1
      ? 'Yesterday'
      : created.year == now.year
      ? DateFormat.MMMMd().format(created)
      : DateFormat.yMMMMd().format(created);
  final time = (use24HourFormat ? DateFormat.Hm() : DateFormat.jm()).format(
    created,
  );
  return (day: day, time: time);
}

/// Back, the title capsule and the item menu float over the media with no
/// scrim, as in Photos. A single tap on the media hides them with the rest
/// of the chrome.
class PhotoViewerTopBar extends StatelessWidget {
  const PhotoViewerTopBar({
    required this.file,
    required this.visible,
    required this.onBack,
    required this.onStar,
    required this.onInfo,
    required this.onDownload,
    required this.onMore,
    this.dark = true,
    this.menuSections,
    super.key,
  });
  final DriveFile? file;
  final bool visible;

  /// Dark chrome (white content) or light chrome over the white backdrop.
  final bool dark;
  final IosMenuSectionsBuilder? menuSections;
  final VoidCallback onBack, onStar, onInfo, onDownload, onMore;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final created = DateTime.tryParse(file?.createdAt ?? '')?.toLocal();
    final title = created == null
        ? null
        : photoViewerTitle(
            created,
            now: DateTime.now(),
            use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final content = dark ? Colors.white : Colors.black;
    final heading = Semantics(
      header: true,
      label: title == null ? 'Photo' : '${title.day}, ${title.time}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title?.day ?? 'Photo',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: content,
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: -.2,
              ),
            ),
            if (title != null)
              Text(
                title.time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: content.withValues(alpha: .8),
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
    return AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  if (ios)
                    NativeGlassButton(
                      label: 'Back',
                      symbol: 'chevron.left',
                      icon: CupertinoIcons.chevron_back,
                      onPressed: onBack,
                      white: dark,
                    )
                  else
                    IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: Icon(Icons.arrow_back, color: content),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: ios
                          ? NativeGlassSurface(
                              key: const ValueKey('photo-viewer-title'),
                              dark: dark,
                              child: heading,
                            )
                          : KeyedSubtree(
                              key: const ValueKey('photo-viewer-title'),
                              child: heading,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (ios && menuSections != null)
                    IosMoreButton(
                      white: dark,
                      menuTitle: file == null
                          ? null
                          : itemStatusText(
                              starred: file!.starred,
                              shared: file!.shared,
                            ),
                      sectionsBuilder: menuSections!,
                    )
                  else if (!ios)
                    IconButton(
                      tooltip: 'More',
                      onPressed: file == null ? null : onMore,
                      icon: Icon(Icons.more_vert, color: content),
                    )
                  else
                    NativeGlassButton(
                      label: 'More',
                      symbol: 'ellipsis',
                      icon: CupertinoIcons.ellipsis,
                      onPressed: file == null ? null : onMore,
                      white: dark,
                    ),
                ],
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
    this.dark = true,
  });
  final DriveFile file;
  final bool infoSelected;

  /// Dark chrome (white glyphs) or light chrome over the white backdrop.
  final bool dark;
  final VoidCallback onStar, onInfo, onDownload;
  final VoidCallback? onShare, onDelete;
  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final content = dark ? Colors.white : Colors.black;
    final capsule = NativeGlassSurface.fallbackColor(dark);
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
            ? IconButton.styleFrom(backgroundColor: capsule)
            : null,
        tooltip: label,
        onPressed: callback,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: content, size: ios ? 22 : 24),
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
              color: capsule,
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
      dark: dark,
      fallback: fallback,
    );
  }
}
