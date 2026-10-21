import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/upload/ui/components/upload_status_ring.dart';
import '../models/drive_models.dart';

/// Whether [file] is an upload still in flight (not finished, failed or
/// cancelled).
bool isUploadInFlight(DriveFile file) =>
    file.isOptimistic &&
    !const {'uploaded', 'failed', 'cancelled'}.contains(file.uploadStatus);

/// Status mark for a file that is still uploading, wherever it is listed
/// (list rows, grid tiles). It is the same ring as the upload capsule and
/// panel, filled by the upload's real progress, so every surface agrees: a
/// blue ring while it transfers, a gray clock or Wi-Fi glyph while it waits.
class UploadRowStatus extends StatelessWidget {
  const UploadRowStatus({
    required this.file,
    this.size = 28,
    this.onImage = false,
    super.key,
  });

  final DriveFile file;
  final double size;

  /// Over a thumbnail: adds an opaque backing so the ring stays legible.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final status = file.uploadStatus;
    final wifi = status == 'waitingForWifi';
    final waiting = wifi || status == 'queued' || status == 'selected';
    final progress = waiting
        ? null
        : (file.uploadProgress ?? 0).clamp(0.0, 1.0);
    final tint = ios
        ? CupertinoDynamicColor.resolve(
            waiting ? IosTint.neutral : IosTint.uploads,
            context,
          )
        : waiting
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    final label = wifi
        ? 'Waiting for Wi-Fi'
        : waiting
        ? 'Waiting to upload'
        : 'Uploading, ${((progress ?? 0) * 100).floor()} percent';
    Widget ring = UploadStatusRing(
      tint: tint,
      icon: wifi
          ? (ios ? CupertinoIcons.wifi : Icons.wifi_rounded)
          : waiting
          ? (ios ? CupertinoIcons.clock : Icons.schedule_rounded)
          : (ios ? CupertinoIcons.arrow_up : Icons.arrow_upward_rounded),
      progress: progress,
      size: size,
      stroke: size >= 28 ? 2.5 : 2,
      iconSize: size * .46,
    );
    if (onImage) {
      ring = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface.withValues(alpha: .92),
        ),
        child: ring,
      );
    }
    return Semantics(label: label, excludeSemantics: true, child: ring);
  }
}
