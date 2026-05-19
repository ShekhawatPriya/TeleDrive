import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.file,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final DriveFile file;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedWash = scheme.primary.withValues(alpha: .12);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Hero(
        tag: 'photo-${file.id}',
        flightShuttleBuilder: (_, __, ___, ____, _____) {
          return MediaThumb(file: file, fit: BoxFit.cover, radius: 0);
        },
        child: AnimatedContainer(
          duration: AppDurations.short3,
          curve: AppEasing.standardDecelerate,
          padding: selected ? const EdgeInsets.all(8) : EdgeInsets.zero,
          color: selected ? selectedWash : Colors.transparent,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(selected ? AppRadii.xs : 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(selectedWash),
                if (isVideoFile(file)) _videoBadge(),
                if (selectMode) _selectionMark(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(Color selectedWash) {
    final thumb = MediaThumb(file: file, fit: BoxFit.cover, radius: 0);
    if (!selected) return thumb;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(selectedWash, BlendMode.srcATop),
      child: thumb,
    );
  }

  Widget _videoBadge() {
    final hasDuration = file.duration != null;
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
      top: 8,
      left: 8,
      child: AnimatedContainer(
        duration: AppDurations.short3,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primary : Colors.black.withValues(alpha: .25),
          border: Border.all(color: scheme.surface, width: 2),
        ),
        child: selected
            ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
            : null,
      ),
    );
  }
}
