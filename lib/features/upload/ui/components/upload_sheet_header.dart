import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../upload_models.dart';

class UploadSheetHeader extends StatelessWidget {
  const UploadSheetHeader({required this.summary, super.key});
  final UploadSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final total = summary.itemCount;
    final done = summary.uploadedCount;
    final completed = total > 0 && done == total;

    final totalBytes = summary.totalBytes;
    final completedBytes = summary.completedBytes;

    final stillGeneratingThumbs = summary.stillGeneratingThumbs;

    final isFailed = summary.failedCount > 0 && summary.activeCount == 0;
    final waitingForWifi = summary.waitingForWifi;

    final title = completed
        ? 'Uploads complete'
        : waitingForWifi
        ? 'Waiting for Wi-Fi'
        : isFailed
        ? 'Upload failed'
        : 'Uploading $total ${total == 1 ? 'file' : 'files'}';

    final subtitle = stillGeneratingThumbs
        ? 'Generating previews…'
        : completed
        ? 'All files uploaded successfully · ${formatFileSize(totalBytes)}'
        : waitingForWifi
        ? 'Mobile data uploads are disabled. Uploads will continue automatically on Wi-Fi.'
        : isFailed
        ? '$done of $total completed · ${summary.failedCount} failed'
        : '$done of $total completed · ${formatFileSize(completedBytes)} of ${formatFileSize(totalBytes)}';

    final showProgress =
        !completed &&
        !waitingForWifi &&
        summary.activeCount > 0 &&
        totalBytes > 0;
    final overallProgress = showProgress ? completedBytes / totalBytes : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isFailed ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: overallProgress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
