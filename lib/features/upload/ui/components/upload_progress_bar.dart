import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Slim, warm-toned progress line.  Replaces Material's
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = dark ? const Color(0xff3d3d3a) : AppColors.warmSand;
    final fill = dark ? AppColors.coral : AppColors.terracotta;

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
