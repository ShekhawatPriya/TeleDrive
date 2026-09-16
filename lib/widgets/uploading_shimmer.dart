import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class UploadingShimmer extends StatelessWidget {
  const UploadingShimmer({
    required this.enabled,
    required this.child,
    required this.borderRadius,
    super.key,
  });
  final bool enabled;
  final Widget child;
  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) {
    if (!enabled ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context))
      return child;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: Shimmer.fromColors(
              baseColor: Colors.transparent,
              highlightColor: scheme.primary.withValues(alpha: .16),
              period: const Duration(milliseconds: 1800),
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
