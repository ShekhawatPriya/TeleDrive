import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../upload_models.dart';
import 'upload_progress_bar.dart';

/// Collapsed pill that floats above the FAB while uploads are running. Tapping
/// expands the modal upload sheet.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final total = summary.itemCount;
    final done = summary.uploadedCount;
    final completed = total > 0 && done == total;
    final waitingForWifi = summary.waitingForWifi;
    final progress = summary.overallProgress;

    final totalBytes = summary.totalBytes;
    final completedBytes = summary.completedBytes;

    return Material(
      color: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: scheme.shadow,
      elevation: AppElevation.level3,
      borderRadius: AppRadii.lgR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      completed
                          ? Icons.check_rounded
                          : waitingForWifi
                          ? Icons.wifi_rounded
                          : Icons.cloud_upload_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          completed
                              ? '$total ${total == 1 ? 'file' : 'files'} uploaded'
                              : waitingForWifi
                              ? 'Waiting for Wi-Fi'
                              : 'Uploading $total ${total == 1 ? 'file' : 'files'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$done of $total · '
                          '${formatFileSize(completedBytes)}/${formatFileSize(totalBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            UploadProgressBar(value: completed ? 1 : progress, height: 4),
          ],
        ),
      ),
    );
  }
}
