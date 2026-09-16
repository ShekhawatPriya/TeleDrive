import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

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
        color: scheme.surface,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 88,
                      child: MediaThumb(
                        file: file,
                        fit: BoxFit.cover,
                        radius: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Information',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            file.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (created != null)
                            Text(
                              DateFormat('MMMM d, yyyy').format(created),
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FactCard(
                        label: 'File size',
                        value: formatFileSize(file.size),
                        width: MediaQuery.textScalerOf(context).scale(14) > 22
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2,
                        icon: Icons.data_usage_rounded,
                      ),
                      _FactCard(
                        label: file.duration != null ? 'Duration' : 'Format',
                        value: file.duration != null
                            ? formatDuration(file.duration!)
                            : formatLabel(file),
                        width: MediaQuery.textScalerOf(context).scale(14) > 22
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2,
                        icon: file.duration != null
                            ? Icons.play_circle_outline
                            : Icons.image_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle('Details'),
                _MetadataGroup(
                  children: [
                    if (file.widthPx != null && file.heightPx != null)
                      _DetailRow(
                        icon: Icons.photo_size_select_actual_outlined,
                        label: 'Dimensions',
                        value: _dimensions(file),
                      ),
                    _DetailRow(
                      icon: Icons.description_outlined,
                      label: 'Type',
                      value: file.mimeType ?? formatLabel(file),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle('Stored in'),
                _MetadataGroup(
                  children: [
                    _DetailRow(
                      icon: Icons.folder_outlined,
                      label: 'Folder',
                      value: folderName ?? 'My Drive',
                    ),
                  ],
                ),
                if (created != null || modified != null) ...[
                  const SizedBox(height: 24),
                  _SectionTitle('Timeline'),
                  _MetadataGroup(
                    children: [
                      if (created != null)
                        _DetailRow(
                          icon: Icons.add_circle_outline,
                          label: 'Created',
                          value: DateFormat(
                            'MMM d, y · h:mm a',
                          ).format(created),
                        ),
                      if (modified != null)
                        _DetailRow(
                          icon: Icons.history,
                          label: 'Modified',
                          value: DateFormat(
                            'MMM d, y · h:mm a',
                          ).format(modified),
                        ),
                    ],
                  ),
                ],
                if ((file.uploadStatus ?? 'available') != 'available' ||
                    _shouldShowPreviewStatus(file)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle('Status'),
                  if ((file.uploadStatus ?? 'available') != 'available')
                    _DetailRow(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Upload',
                      value: formatUploadStatus(file),
                    ),
                  if (_shouldShowPreviewStatus(file))
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

  bool _shouldShowPreviewStatus(DriveFile file) {
    final status = file.previewStatus ?? '';
    if (status.isEmpty || status == 'available') return false;
    // TDLib-managed files can fetch the preview/original on demand even when
    // the server-side preview status is 'unavailable', so don't surface a
    // misleading warning row.
    if (file.hasTelegramMediaRefs) {
      return false;
    }
    return true;
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
          color: theme.colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
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

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
  });
  final String label;
  final String value;
  final IconData icon;
  final double width;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(height: 16),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetadataGroup extends StatelessWidget {
  const _MetadataGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 64),
          children[i],
        ],
      ],
    ),
  );
}
