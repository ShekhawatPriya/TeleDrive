import 'package:flutter/material.dart';

/// Slim progress line. Replaces Material's
/// LinearProgressIndicator so we control radius, height, and tones.
class UploadProgressBar extends StatelessWidget {
  const UploadProgressBar({
    required this.value,
    this.height = 4,
    this.indeterminate = false,
    super.key,
  });

  final double value;
  final double height;
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.surfaceContainerHighest;
    final fill = scheme.primary;

    if (indeterminate) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: LinearProgressIndicator(
            backgroundColor: track,
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: track),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(height: height, color: fill),
          ),
        ],
      ),
    );
  }
}
