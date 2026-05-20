import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';

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
            final donut = _DonutChart(
              used: used,
              categories: categories,
            );
            final legend = _StorageLegend(
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

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.used, required this.categories});

  final int used;
  final List<StorageCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasData = used > 0;

    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _DonutPainter(
              used: used,
              categories: categories,
              trackColor: scheme.surfaceContainerHighest,
              emptyColor: scheme.outlineVariant,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasData ? formatFileSize(used) : '0 B',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasData ? 'used' : 'no files',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.used,
    required this.categories,
    required this.trackColor,
    required this.emptyColor,
  });

  final int used;
  final List<StorageCategory> categories;
  final Color trackColor;
  final Color emptyColor;

  static const _stroke = 14.0;
  static const _gap = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - _stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );

    if (used <= 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 1.6,
        false,
        Paint()
          ..color = emptyColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _stroke,
      );
      return;
    }

    final segments = categories.where((c) => c.bytes > 0).toList();
    final gapTotal = segments.length > 1 ? segments.length * _gap : 0.0;
    final available = math.pi * 2 - gapTotal;

    var start = -math.pi / 2 + (segments.length > 1 ? _gap / 2 : 0);
    for (final seg in segments) {
      final sweep = (seg.bytes / used) * available;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeCap = segments.length == 1 ? StrokeCap.butt : StrokeCap.round
          ..strokeWidth = _stroke,
      );
      start += sweep + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.used != used ||
        old.categories != categories ||
        old.trackColor != trackColor ||
        old.emptyColor != emptyColor;
  }
}

class _StorageLegend extends StatelessWidget {
  const _StorageLegend({required this.used, required this.categories});

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
