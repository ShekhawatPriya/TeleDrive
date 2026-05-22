import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';

class PhotoDetailsSheet extends StatelessWidget {
  const PhotoDetailsSheet({
    required this.file,
    required this.folderName,
    required this.scrollController,
    super.key,
  });

  final DriveFile file;
  final String? folderName;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final modified = DateTime.tryParse(file.modifiedAt)?.toLocal();
    final created = DateTime.tryParse(file.createdAt)?.toLocal();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.sheetTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    file.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (modified != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      DateFormat('EEE, MMM d, y · h:mm a').format(modified),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _SectionTitle('Details'),
                if (file.widthPx != null && file.heightPx != null)
                  _DetailRow(
                    icon: Icons.photo_size_select_actual_outlined,
                    label: 'Dimensions',
                    value: _dimensions(file),
                  ),
                _DetailRow(
                  icon: Icons.sd_storage_outlined,
                  label: 'Size',
                  value: formatFileSize(file.size),
                ),
                _DetailRow(
                  icon: Icons.code,
                  label: 'Type',
                  value: file.mimeType ?? formatLabel(file),
                ),
                if (file.duration != null)
                  _DetailRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: formatDuration(file.duration!),
                  ),
                const SizedBox(height: AppSpacing.md),
                _SectionTitle('Location'),
                _DetailRow(
                  icon: Icons.folder_outlined,
                  label: 'Folder',
                  value: folderName ?? 'My Drive',
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionTitle('Timeline'),
                if (created != null)
                  _DetailRow(
                    icon: Icons.add_circle_outline,
                    label: 'Created',
                    value: DateFormat('MMM d, y · h:mm a').format(created),
                  ),
                if (modified != null)
                  _DetailRow(
                    icon: Icons.history,
                    label: 'Modified',
                    value: DateFormat('MMM d, y · h:mm a').format(modified),
                  ),
                if ((file.uploadStatus ?? 'available') != 'available' ||
                    (file.previewStatus ?? '').isNotEmpty &&
                        file.previewStatus != 'available') ...[
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle('Status'),
                  if ((file.uploadStatus ?? 'available') != 'available')
                    _DetailRow(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Upload',
                      value: formatUploadStatus(file),
                    ),
                  if ((file.previewStatus ?? '').isNotEmpty &&
                      file.previewStatus != 'available')
                    _DetailRow(
                      icon: Icons.preview_outlined,
                      label: 'Preview',
                      value: file.previewStatus!,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dimensions(DriveFile file) {
    final w = file.widthPx!;
    final h = file.heightPx!;
    final mp = (w * h) / 1000000;
    return '$w × $h · ${mp.toStringAsFixed(mp >= 10 ? 0 : 1)} MP';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
