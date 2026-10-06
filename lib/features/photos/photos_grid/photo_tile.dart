import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/file_list_tile.dart';
import '../../../widgets/item_status_indicators.dart';
import '../../../widgets/starred_badge.dart';
import '../../../widgets/media_thumb.dart';
import '../../drive/components/drive_item_context_menu.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.file,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.onSelect,
    super.key,
  });

  final DriveFile file;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedWash = scheme.primary.withValues(alpha: .12);
    return LayoutBuilder(
      builder: (context, constraints) {
        final duration = file.duration;
        final durationText = duration == null ? null : formatDuration(duration);
        final durationPainter = durationText == null
            ? null
            : (TextPainter(
                text: TextSpan(
                  text: durationText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                textScaler: MediaQuery.textScalerOf(context),
                textDirection: Directionality.of(context),
              )..layout());
        final showDuration =
            durationPainter != null &&
            durationPainter.width + 50 <= constraints.maxWidth;
        durationPainter?.dispose();
        return DriveItemContextMenu(
          file: file,
          enabled: !selectMode && TickerMode.valuesOf(context).enabled,
          onOpen: onTap,
          onSelect: onSelect ?? onLongPress,
          child: Semantics(
            button: true,
            label: isVideoFile(file) && durationText != null
                ? '${file.name}, video, $durationText'
                : file.name,
            selected: selected,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress:
                  Theme.of(context).platform == TargetPlatform.iOS &&
                      !selectMode
                  ? null
                  : onLongPress,
              child: Hero(
                tag: 'photo-${file.id}',
                flightShuttleBuilder: (_, __, ___, ____, _____) {
                  return MediaThumb(file: file, fit: BoxFit.cover, radius: 0);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : AppDurations.short3,
                      curve: AppEasing.standardDecelerate,
                      padding: selected
                          ? const EdgeInsets.all(8)
                          : EdgeInsets.zero,
                      color: selected ? selectedWash : Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Theme.of(context).platform == TargetPlatform.iOS
                              ? 4
                              : 14,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _thumb(
                              selectedWash,
                              constraints.maxWidth *
                                  MediaQuery.devicePixelRatioOf(context),
                            ),
                            if (isVideoFile(file))
                              _videoBadge(showDuration: showDuration),
                            if (Theme.of(context).platform !=
                                    TargetPlatform.iOS &&
                                !file.isOptimistic &&
                                (file.starred || file.shared))
                              Positioned(
                                right: 8,
                                top: 8,
                                child: ItemStatusIndicators(
                                  starred: file.starred,
                                  shared: file.shared,
                                ),
                              ),
                            if (Theme.of(context).platform ==
                                    TargetPlatform.iOS &&
                                file.starred &&
                                !file.isOptimistic)
                              const Positioned(
                                right: 8,
                                top: 8,
                                child: StarredBadge(size: 16),
                              ),
                            if (Theme.of(context).platform ==
                                    TargetPlatform.iOS &&
                                file.shared &&
                                !file.isOptimistic)
                              _sharedBadge(),
                          ],
                        ),
                      ),
                    ),
                    if (selectMode) _selectionMark(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(Color selectedWash, double pixels) {
    final thumb = MediaThumb(
      file: file,
      fit: BoxFit.cover,
      radius: 0,
      decodeWidth: pixels <= 320
          ? 320
          : pixels <= 640
          ? 640
          : 960,
    );
    if (!selected) return thumb;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(selectedWash, BlendMode.srcATop),
      child: thumb,
    );
  }

  Widget _sharedBadge() {
    return const Positioned(right: 8, bottom: 8, child: SharedBadge(size: 20));
  }

  Widget _videoBadge({required bool showDuration}) {
    final hasDuration = showDuration && file.duration != null;
    return Positioned(
      left: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasDuration ? 8 : 6,
            vertical: 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 14,
              ),
              if (hasDuration) ...[
                const SizedBox(width: 2),
                Text(
                  formatDuration(file.duration!),
                  key: ValueKey('photo-duration-${file.id}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionMark(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 6,
      left: 6,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDurations.short3,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? scheme.primary
              : Colors.black.withValues(alpha: .25),
          border: Border.all(color: scheme.surface, width: 2),
        ),
        child: selected
            ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
            : null,
      ),
    );
  }
}
