import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';

class MetadataBlock extends StatelessWidget {
  const MetadataBlock({required this.file, super.key});
  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <_MetaRow>[
      _MetaRow('Type', formatLabel(file)),
      _MetaRow('Size', formatFileSize(file.size)),
      _MetaRow('Modified', formatDate(file.modifiedAt)),
      if (file.createdAt.isNotEmpty && file.createdAt != file.modifiedAt)
        _MetaRow('Created', formatDate(file.createdAt)),
      if (file.mimeType != null && file.mimeType!.isNotEmpty)
        _MetaRow('MIME', file.mimeType!),
      if (file.widthPx != null && file.heightPx != null)
        _MetaRow('Dimensions', '${file.widthPx} × ${file.heightPx}'),
      if (file.duration != null)
        _MetaRow('Duration', formatDuration(file.duration!)),
      _MetaRow('Upload', _humanize(file.uploadStatus ?? 'available')),
      _MetaRow(
        'Preview',
        _isPreviewAvailable(file) ? 'Available' : 'Unavailable',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i != 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 18,
                  endIndent: 18,
                  color: scheme.outlineVariant.withValues(alpha: .4),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].value,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.visible,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _humanize(String status) {
    if (status.isEmpty) return '—';
    if (status.length <= 1) return status.toUpperCase();
    return status[0].toUpperCase() + status.substring(1);
  }

  bool _isPreviewAvailable(DriveFile file) {
    if (file.previewStatus == 'available') return true;
    if (file.previewUrl != null) return true;
    if (file.hasTelegramMediaRefs) {
      return true;
    }
    return false;
  }
}

class _MetaRow {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;
}
