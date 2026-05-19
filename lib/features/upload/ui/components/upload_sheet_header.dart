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

    final stillGeneratingThumbs =
        completed &&
        upload.items.any((i) {
          final kind = detectFileKind(i.name, i.mimeType);
          final previewable = kind == FileKind.image || kind == FileKind.video;
          return previewable && !i.thumbnailReady;
        });

    final title = completed
        ? 'All set'
        : '$total ${total == 1 ? 'file' : 'files'}';
    final subtitle = stillGeneratingThumbs
        ? 'Generating previews...'
        : '$done of $total uploaded \u00b7 '
              '${formatFileSize(completedBytes)} of ${formatFileSize(totalBytes)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface.withValues(alpha: .6),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
