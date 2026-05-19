import 'package:flutter/material.dart';

/// Slim progress line wrapper around M3 [LinearProgressIndicator] with
/// project-tuned defaults (4dp thickness, theme tints).
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: indeterminate ? null : value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      ),
    );
  }
}
