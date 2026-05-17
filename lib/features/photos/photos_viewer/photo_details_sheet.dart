import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final modified = DateTime.tryParse(file.modifiedAt)?.toLocal();
    final created = DateTime.tryParse(file.createdAt)?.toLocal();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(
            file.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            modified == null
                ? formatDate(file.modifiedAt)
                : DateFormat('EEE, MMM d, y · h:mm a').format(modified),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 16),
          _SectionTitle('Location'),
          _DetailRow(
            icon: Icons.folder_outlined,
            label: 'Folder',
            value: folderName ?? 'My Drive',
          ),
          const SizedBox(height: 16),
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
                  file.previewStatus != 'available')
            ...[
              const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurface.withValues(alpha: .7)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
