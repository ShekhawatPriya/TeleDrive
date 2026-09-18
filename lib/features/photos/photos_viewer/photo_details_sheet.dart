import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';

/// Metadata is intentionally limited to facts supplied by the Drive model.
/// Created/modified timestamps are not represented as EXIF capture dates.
class PhotoDetailsSheet extends StatelessWidget {
  const PhotoDetailsSheet({
    required this.file,
    required this.folderName,
    required this.scrollController,
    this.integrated = false,
    super.key,
  });
  final DriveFile file;
  final String? folderName;
  final ScrollController scrollController;
  final bool integrated;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final valueStyle =
        (ios ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
            ?.copyWith(color: scheme.onSurface);
    final created = DateTime.tryParse(file.createdAt)?.toLocal();
    final modified = DateTime.tryParse(file.modifiedAt)?.toLocal();
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: valueStyle),
        ],
      ),
    );
    Widget group(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(ios ? 26 : 24),
        child: ColoredBox(
          color: scheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: .5,
                    color: scheme.outlineVariant,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
    return ColoredBox(
      color: scheme.surface,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          16,
          integrated && ios ? 16 : 8,
          16,
          integrated ? 144 + MediaQuery.paddingOf(context).bottom : 32,
        ),
        children: [
          if (!integrated)
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          group([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (created != null)
                    Text(
                      DateFormat('EEEE · d MMM y · HH:mm').format(created),
                      style: valueStyle,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    file.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      file.mimeType ?? 'Media file',
                      style: valueStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      formatLabel(file),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            row(
              'File size',
              [
                if (file.widthPx != null && file.heightPx != null)
                  '${file.widthPx} × ${file.heightPx}',
                formatFileSize(file.size),
                if (file.duration != null) formatDuration(file.duration!),
              ].join(' · '),
            ),
          ]),
          group([row('Stored in', folderName ?? 'My Drive')]),
          group([
            if (created != null)
              row(
                'Added to Drive',
                DateFormat('d MMM y · HH:mm').format(created),
              ),
            if (modified != null)
              row('Modified', DateFormat('d MMM y · HH:mm').format(modified)),
          ]),
          if ((file.uploadStatus ?? 'available') != 'available')
            group([row('Upload', formatUploadStatus(file))]),
          if (!file.hasTelegramMediaRefs &&
              (file.previewStatus ?? '').isNotEmpty &&
              file.previewStatus != 'available')
            group([row('Preview', file.previewStatus!)]),
        ],
      ),
    );
  }
}
