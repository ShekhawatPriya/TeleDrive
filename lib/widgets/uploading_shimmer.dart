import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class UploadingShimmer extends StatefulWidget {
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
  State<UploadingShimmer> createState() => _UploadingShimmerState();
}

class _UploadingShimmerState extends State<UploadingShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.enabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant UploadingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Opacity(
                  opacity: _pulseAnimation.value,
                  child: Shimmer.fromColors(
                    baseColor: scheme.primaryContainer.withValues(alpha: .35),
                    highlightColor: scheme.primary.withValues(alpha: .75),
                    period: const Duration(milliseconds: 1200),
                    child: const ColoredBox(
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
