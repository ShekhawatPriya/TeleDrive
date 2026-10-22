import 'package:flutter/material.dart';

import '../../../../core/utils/file_type_detector.dart';

import '../../upload_models.dart';
import '../upload_summary_presentation.dart';
import 'status_capsule.dart';
import 'upload_status_ring.dart';

/// A single accessible target for reopening the transfer list.
class UploadCollapsedBar extends StatelessWidget {
  const UploadCollapsedBar({
    required this.summary,
    required this.onTap,
    super.key,
  });

  final UploadSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final percent = '${uploadPercent(summary.overallProgress)}%';
    return StatusCapsule(
      title: ios ? summary.capsuleTitle : summary.statusTitle,
      detail: summary.stillGeneratingThumbs
          ? 'Finishing previews…'
          : summary.countLabel,
      trailing: summary.progressing
          ? percent
          : summary.needsAttention
          ? 'Review'
          : null,
      tint: uploadSummaryTint(context, summary),
      icon: uploadSummaryIcon(summary),
      materialIcon: summary.complete
          ? Icons.check_rounded
          : summary.waitingForWifi
          ? Icons.wifi_rounded
          : summary.needsAttention
          ? Icons.error_outline
          : Icons.arrow_upward_rounded,
      progress: summary.progressing ? summary.overallProgress : null,
      attention: summary.needsAttention,
      semanticLabel:
          '${summary.statusTitle}. ${summary.countLabel}. '
          '${summary.detailLabel}. Show upload details',
      onTap: onTap,
    );
  }
}
