import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';
import '../photos_filter.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.file,
    required this.filter,
    super.key,
  });

  final DriveFile file;
  final PhotosFilter filter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '/photos/view/${file.id}?filter=${filter.queryValue}',
      ),
      child: Hero(
        tag: 'photo-${file.id}',
        flightShuttleBuilder: (_, animation, __, ___, ____) {
          return MediaThumb(file: file, fit: BoxFit.cover, radius: 0);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaThumb(file: file, fit: BoxFit.cover, radius: 0),
            if (isVideoFile(file)) _videoBadge(),
          ],
        ),
      ),
    );
  }

  Widget _videoBadge() {
    return Positioned(
      right: 4,
      bottom: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 12),
              const SizedBox(width: 2),
              Text(
                file.duration == null ? '' : formatDuration(file.duration!),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
