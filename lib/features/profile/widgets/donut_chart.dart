import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/file_type_detector.dart';
import 'storage_donut_card.dart';

class DonutChart extends StatelessWidget {
  const DonutChart({
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
