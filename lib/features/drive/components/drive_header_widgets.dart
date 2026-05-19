import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';

class DriveStoragePill extends StatelessWidget {
  const DriveStoragePill({required this.used, super.key});
  final int used;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatFileSize(used)} used',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: used > 0 ? 1 : 0,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriveSectionHeader extends StatelessWidget {
  const DriveSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}
