import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../upload_models.dart';
import '../upload_summary_presentation.dart';

/// iOS status mark shared by the floating capsule, the upload panel and its
/// rows: a tinted disc with a progress ring while running, and a solid glyph
/// once settled — the in-app counterpart of the Live Activity ring.
class UploadStatusRing extends StatelessWidget {
  const UploadStatusRing({
    required this.tint,
    required this.icon,
    this.progress,
    this.size = 44,
    this.stroke = 3,
    this.iconSize,
    super.key,
  });

  final Color tint;
  final IconData icon;

  /// Null draws the settled disc without a ring.
  final double? progress;
  final double size;
  final double stroke;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final running = progress != null;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: running ? .12 : .18),
            ),
            child: const SizedBox.expand(),
          ),
          if (running)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress!.clamp(0, 1)),
                duration: reduced ? Duration.zero : AppDurations.medium4,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  painter: _RingPainter(
                    progress: value,
                    stroke: stroke,
                    color: tint,
                    track: tint.withValues(alpha: .22),
                  ),
                ),
              ),
            ),
          AnimatedSwitcher(
            duration: reduced ? Duration.zero : AppDurations.medium2,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: .6, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: iconSize ?? size * .43,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double progress;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.2832, false, paint..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * progress.clamp(.02, 1),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.color != color ||
      old.track != track;
}

/// Capsule progress line in the Live Activity's style: tinted fill on a
/// faint track of the same hue.
class UploadTintBar extends StatelessWidget {
  const UploadTintBar({
    required this.value,
    required this.tint,
    this.height = 6,
    super.key,
  });

  final double value;
  final Color tint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Upload progress',
      value: '${(value.clamp(0, 1) * 100).floor()}%',
      child: Container(
        height: height,
        decoration: ShapeDecoration(
          color: tint.withValues(alpha: .16),
          shape: const StadiumBorder(),
        ),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: reduced ? Duration.zero : AppDurations.medium4,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v == 0 ? 0 : v.clamp(.02, 1),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: tint,
                shape: const StadiumBorder(),
              ),
              child: SizedBox(height: height),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status colours shared with the Live Activity: blue running, green done,
/// orange when some failed, red when none made it, gray while waiting.
Color uploadSummaryTint(BuildContext context, UploadSummary summary) {
  final Color color;
  if (summary.complete) {
    color = CupertinoColors.systemGreen;
  } else if (summary.waitingForWifi) {
    color = IosTint.neutral;
  } else if (summary.needsAttention) {
    color = summary.uploadedCount > 0
        ? CupertinoColors.systemOrange
        : CupertinoColors.systemRed;
  } else {
    color = IosTint.uploads;
  }
  return CupertinoDynamicColor.resolve(color, context);
}

IconData uploadSummaryIcon(UploadSummary summary) => summary.complete
    ? CupertinoIcons.checkmark_alt
    : summary.waitingForWifi
    ? CupertinoIcons.wifi
    : summary.needsAttention
    ? CupertinoIcons.exclamationmark
    : CupertinoIcons.arrow_up;

/// Grouped iOS colours for the upload panel: page and inset card.
({Color page, Color card}) iosUploadPanelColors(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? (page: scheme.surfaceContainerLow, card: scheme.surfaceContainerHigh)
    : (page: scheme.surface, card: scheme.surfaceContainerLowest);
