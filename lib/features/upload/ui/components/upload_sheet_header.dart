import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../../../models/drive_models.dart';
import '../../upload_controller.dart';

class UploadSheetHeader extends StatelessWidget {
  const UploadSheetHeader({required this.upload, super.key});
  final UploadController upload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final total = upload.items.length;
    final done = upload.uploadedCount;
    final completed = total > 0 && done == total;

    final totalBytes = upload.items.fold<int>(0, (s, i) => s + i.size);
    final completedBytes = upload.items.fold<int>(
      0,
      (s, i) => s + (i.progress * i.size).round(),
    );

    final stillGeneratingThumbs = completed &&
        upload.items.any((i) {
          final kind = detectFileKind(i.name, i.mimeType);
          final previewable = kind == FileKind.image || kind == FileKind.video;
          return previewable && !i.thumbnailReady;
        });

    final isFailed = upload.failedCount > 0 && upload.activeCount == 0;

    final title = completed
        ? 'Uploads complete'
        : isFailed
            ? 'Upload failed'
            : 'Uploading $total ${total == 1 ? 'file' : 'files'}';

    final subtitle = stillGeneratingThumbs
        ? 'Generating previews…'
        : completed
            ? 'All files uploaded successfully · ${formatFileSize(totalBytes)}'
            : isFailed
                ? '$done of $total completed · ${upload.failedCount} failed'
                : '$done of $total completed · ${formatFileSize(completedBytes)} of ${formatFileSize(totalBytes)}';

    final showProgress = !completed && upload.activeCount > 0 && totalBytes > 0;
    final overallProgress = showProgress ? completedBytes / totalBytes : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
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
