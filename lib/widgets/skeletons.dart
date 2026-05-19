import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/app_theme.dart';

class SkeletonList extends StatelessWidget {
  const SkeletonList({this.count = 8, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 120),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outline.withValues(alpha: .72)),
          ),
        ),
      ),
    );
  }
}
