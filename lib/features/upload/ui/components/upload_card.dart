import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_type_detector.dart';
import '../../upload_controller.dart';
import '../upload_status_label.dart';
import 'upload_progress_bar.dart';
import 'upload_thumb_slot.dart';

/// Persistent card for one upload item — visible for the entire lifecycle of
/// the upload (queued → uploading → done / failed). Cards never overlap or
/// collapse; the active uploading file is highlighted by a primary border.
class UploadCard extends StatelessWidget {
  const UploadCard({required this.item, super.key});
  final UploadItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isQueued = item.status == UploadStatus.selected ||
        item.status == UploadStatus.queued;
    final isActive = uploadIsActive(item.status);
    final isUploaded = item.status == UploadStatus.uploaded;
    final isFailed = item.status == UploadStatus.failed;

    return Opacity(
      opacity: isQueued ? 0.7 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdR,
          side: isActive
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UploadThumbSlot(item: item),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _StatusLine(item: item),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    formatFileSize(item.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isUploaded)
                _UploadedStrip(accent: scheme.primary)
              else if (isFailed)
                const SizedBox(height: 4)
              else
                UploadProgressBar(value: item.progress),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.item});
  final UploadItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = uploadStatusLabel(item.status);
    final hasError = item.status == UploadStatus.failed && item.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: hasError ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _UploadedStrip extends StatelessWidget {
  const _UploadedStrip({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_rounded, size: 16, color: accent),
        const SizedBox(width: 6),
        Text(
          'Done',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent),
        ),
      ],
    );
  }
}
