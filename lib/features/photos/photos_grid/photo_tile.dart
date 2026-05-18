import 'package:flutter/material.dart';

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

  static const _terracotta = Color(0xFFC96442);
  static const _ivory = Color(0xFFFAF9F5);

  @override
  Widget build(BuildContext context) {
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: selected ? const EdgeInsets.all(8) : EdgeInsets.zero,
          color: selected
              ? _terracotta.withValues(alpha: .12)
              : Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(selected ? 6 : 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(),
                if (isVideoFile(file)) _videoBadge(),
                if (selectMode) _selectionMark(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb() {
    final thumb = MediaThumb(file: file, fit: BoxFit.cover, radius: 0);
    if (!selected) return thumb;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        _terracotta.withValues(alpha: .18),
        BlendMode.srcATop,
      ),
      child: thumb,
    );
  }

  Widget _videoBadge() {
    final hasDuration = file.duration != null;
    return Positioned(
      left: 6,
      bottom: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasDuration ? 7 : 5,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 13,
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
    return Positioned(
      top: 6,
      left: 6,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? _terracotta : Colors.black.withValues(alpha: .25),
          border: Border.all(
            color: _ivory,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 14, color: _ivory)
            : null,
      ),
    );
  }
}
