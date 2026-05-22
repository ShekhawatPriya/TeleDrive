import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import 'storage_donut_card.dart';

class StorageLegend extends StatelessWidget {
  const StorageLegend({
    required this.used,
    required this.categories,
    super.key,
  });

  final int used;
  final List<StorageCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          _LegendRow(category: categories[i], total: used),
          if (i < categories.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        Container(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                used == 0
                    ? 'No storage used yet'
                    : '${formatFileSize(used)} on Telegram',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.category, required this.total});

  final StorageCategory category;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = total == 0 ? 0.0 : category.bytes / total;
    final pctLabel = pct == 0
        ? '0%'
        : pct < 0.001
        ? '<0.1%'
        : '${(pct * 100).toStringAsFixed(pct < 0.1 ? 1 : 0)}%';

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: category.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            category.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ),
        Text(
          formatFileSize(category.bytes),
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 44,
          child: Text(
            pctLabel,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
