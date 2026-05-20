import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/drive_models.dart';
import 'donut_chart.dart';
import 'storage_legend.dart';

class StorageCategory {
  const StorageCategory({
    required this.label,
    required this.bytes,
    required this.color,
  });
  final String label;
  final int bytes;
  final Color color;
}

List<StorageCategory> buildStorageCategories(
  List<DriveFile> files,
  ColorScheme scheme,
) {
  var photos = 0, videos = 0, documents = 0, other = 0;
  for (final file in files) {
    if (file.kind == FileKind.image) {
      photos += file.size;
    } else if (file.kind == FileKind.video) {
      videos += file.size;
    } else if ({
      FileKind.pdf,
      FileKind.doc,
      FileKind.sheet,
      FileKind.slides,
      FileKind.code,
      FileKind.text,
    }.contains(file.kind)) {
      documents += file.size;
    } else {
      other += file.size;
    }
  }
  return [
    StorageCategory(label: 'Photos', bytes: photos, color: scheme.primary),
    StorageCategory(label: 'Videos', bytes: videos, color: scheme.tertiary),
    StorageCategory(
      label: 'Documents',
      bytes: documents,
      color: scheme.secondary,
    ),
    StorageCategory(
      label: 'Other',
      bytes: other,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
    ),
  ];
}

class StorageDonutCard extends StatelessWidget {
  const StorageDonutCard({
    required this.used,
    required this.categories,
    this.embed = false,
    super.key,
  });

  final int used;
  final List<StorageCategory> categories;
  final bool embed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Storage',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: AppRadii.smR,
              ),
              child: Text(
                'Telegram',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 360;
            final donut = DonutChart(
              used: used,
              categories: categories,
            );
            final legend = StorageLegend(
              used: used,
              categories: categories,
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: donut),
                  const SizedBox(height: AppSpacing.md),
                  legend,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                donut,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: legend),
              ],
            );
          },
        ),
      ],
    );

    if (embed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: content,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: content,
      ),
    );
  }
}
