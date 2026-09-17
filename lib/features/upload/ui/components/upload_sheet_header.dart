import 'package:flutter/material.dart';

import '../../upload_models.dart';
import '../upload_summary_presentation.dart';
import 'upload_progress_bar.dart';

class UploadSheetHeader extends StatelessWidget {
  const UploadSheetHeader({required this.summary, super.key});
  final UploadSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uploads', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            summary.statusTitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: summary.needsAttention ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(summary.detailLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          UploadProgressBar(value: summary.overallProgress),
          const SizedBox(height: 8),
          Text(summary.countLabel, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
