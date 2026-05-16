import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonList extends StatelessWidget {
  const SkeletonList({this.count = 8, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.secondary.withValues(alpha: .55);
    final highlight = Theme.of(context).colorScheme.surface;
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
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
