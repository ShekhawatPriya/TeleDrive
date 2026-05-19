import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../upload_controller.dart';
import '../upload_status_label.dart';
import 'upload_progress_bar.dart';
import 'upload_thumb_slot.dart';

/// Redesigned list-style card for one upload item — fully complying with Material 3.
/// Features high typographic scannability, clear hierarchical arrangement,
/// and trailing controls for cancelling, retrying, or dismissing items.
class UploadCard extends ConsumerWidget {
  const UploadCard({required this.item, super.key});
  final UploadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isQueued = item.status == UploadStatus.selected ||
        item.status == UploadStatus.queued;
    final isActive = uploadIsActive(item.status);
    final isUploaded = item.status == UploadStatus.uploaded;
    final isFailed = item.status == UploadStatus.failed;

    // Elegant Material 3 outlines to distinguish states
    final border = isActive
        ? Border.all(color: scheme.primary.withValues(alpha: 0.5), width: 1.5)
        : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3), width: 1);

    return Opacity(
      opacity: isQueued ? 0.75 : 1.0,
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadii.mdR,
          border: border,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UploadThumbSlot(item: item),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filename: highly scannable and bold
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isFailed ? scheme.error : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Meta Information Row
                      Row(
                        children: [
                          Text(
                            formatFileSize(item.size),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFailed && item.error != null
                                  ? item.error!
                                  : uploadStatusLabel(item.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isFailed
                                    ? scheme.error
                                    : (isUploaded
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant),
                                fontWeight: isUploaded
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Trailing Action Controls
                if (isUploaded)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: scheme.primary,
                      size: 24,
                    ),
                  )
                else if (isFailed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(uploadControllerProvider)
                            .confirmUpload(),
                        icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                        tooltip: 'Retry',
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(uploadControllerProvider)
                            .removeFailed(item.localId),
                        icon: Icon(Icons.close_rounded, color: scheme.error),
                        tooltip: 'Dismiss',
                      ),
                    ],
                  )
                else if (item.status == UploadStatus.cancelling)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else // queued / in-progress
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(uploadControllerProvider)
                        .cancelItem(item.localId),
                    icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                    tooltip: 'Cancel',
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: AppSpacing.md),
              UploadProgressBar(value: item.progress, height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
