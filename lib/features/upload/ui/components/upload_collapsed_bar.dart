import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/adaptive_surface.dart';
import '../../upload_models.dart';
import '../upload_summary_presentation.dart';
import 'upload_status_ring.dart';

/// A single accessible target for reopening the transfer list.
class UploadCollapsedBar extends StatelessWidget {
  const UploadCollapsedBar({
    required this.summary,
    required this.onTap,
    super.key,
  });

  final UploadSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final semanticLabel =
        '${summary.statusTitle}. ${summary.countLabel}. '
        '${summary.detailLabel}. Show upload details';
    if (ios) {
      return Semantics(
        button: true,
        onTap: onTap,
        label: semanticLabel,
        excludeSemantics: true,
        child: _IosStatusCapsule(summary: summary, onOpen: onTap),
      );
    }
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (summary.progressing)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: summary.overallProgress.clamp(0, 1),
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.outlineVariant,
                      color: scheme.primary,
                    ),
                  ),
                Icon(
                  summary.complete
                      ? (ios ? CupertinoIcons.check_mark : Icons.check_rounded)
                      : summary.waitingForWifi
                      ? (ios ? CupertinoIcons.wifi : Icons.wifi_rounded)
                      : summary.needsAttention
                      ? (ios
                            ? CupertinoIcons.exclamationmark_circle
                            : Icons.error_outline)
                      : (ios
                            ? CupertinoIcons.arrow_up
                            : Icons.arrow_upward_rounded),
                  size: summary.progressing ? 16 : 24,
                  color: summary.needsAttention ? scheme.error : scheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.statusTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  summary.stillGeneratingThumbs
                      ? 'Finishing previews…'
                      : summary.countLabel,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            ios ? CupertinoIcons.chevron_up : Icons.keyboard_arrow_up_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      onTap: onTap,
      label: semanticLabel,
      excludeSemantics: true,
      child: ios
          ? AdaptiveSurface(
              radius: AppRadii.xl,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onTap,
                child: content,
              ),
            )
          : Material(
              color: scheme.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              elevation: AppElevation.level2,
              borderRadius: AppRadii.xlR,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

/// iOS floating status: a 60-point capsule that pairs with the Add button,
/// in the anatomy of Apple's floating mini-player — leading status disc,
/// two lines of text, one trailing accent — on the same glass as other
/// floating controls. Pressing scales it; tapping or dragging it upward
/// expands it into the upload panel.
class _IosStatusCapsule extends StatefulWidget {
  const _IosStatusCapsule({required this.summary, required this.onOpen});

  final UploadSummary summary;
  final VoidCallback onOpen;

  @override
  State<_IosStatusCapsule> createState() => _IosStatusCapsuleState();
}

class _IosStatusCapsuleState extends State<_IosStatusCapsule> {
  static const _height = 60.0;

  /// Upward travel or fling that counts as "expand".
  static const _openDistance = -22.0;
  static const _openVelocity = -350.0;

  bool _pressed = false;
  double _drag = 0;

  void _end(DragEndDetails details) {
    final open =
        _drag <= _openDistance ||
        (details.primaryVelocity ?? 0) <= _openVelocity;
    setState(() {
      _drag = 0;
      _pressed = false;
    });
    if (open) widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final tint = uploadSummaryTint(context, summary);
    final motion = reduced ? Duration.zero : AppDurations.medium2;
    // One line keeps the capsule shape. Enlarged text wraps instead of
    // clipping, and the trailing accent folds into the second line.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final lines = large ? 3 : 1;
    final spring = reduced ? Curves.linear : const IosSpringCurve(damping: .7);

    final percent = '${(summary.overallProgress.clamp(0, 1) * 100).floor()}%';
    final trailing = large
        ? null
        : summary.progressing
        ? percent
        : summary.needsAttention
        ? 'Review'
        : null;
    final detail = summary.stillGeneratingThumbs
        ? 'Finishing previews…'
        : large && summary.progressing
        ? '${summary.countLabel} · $percent'
        : summary.countLabel;

    final disc = UploadStatusRing(
      tint: tint,
      icon: uploadSummaryIcon(summary),
      progress: summary.progressing ? summary.overallProgress : null,
      iconSize: 19,
    );
    final text = AnimatedSwitcher(
      duration: motion,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Column(
        key: ValueKey(summary.capsuleTitle),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.capsuleTitle,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _height),
      child: large
          // Accessibility sizes: the disc sits above the text so words keep
          // the capsule's full width instead of breaking mid-word.
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [disc, const SizedBox(height: 8), text],
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
              child: Row(
                children: [
                  disc,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      trailing,
                      style: TextStyle(
                        fontSize: summary.progressing ? 17 : 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: tint,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Measure travel from touch-down so the expand distance is what the
      // finger actually moved, not what remains after touch slop.
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onOpen();
      },
      onVerticalDragStart: (_) => setState(() => _pressed = true),
      onVerticalDragUpdate: (details) => setState(
        // Follows the finger upward with resistance; barely moves down.
        () => _drag = (_drag + details.delta.dy).clamp(-60.0, 12.0),
      ),
      onVerticalDragEnd: _end,
      child: AnimatedSlide(
        offset: Offset(0, _drag * .35 / _height),
        duration: _drag == 0 ? motion : Duration.zero,
        curve: spring,
        child: AnimatedScale(
          scale: _pressed ? .96 : 1,
          duration: reduced ? Duration.zero : AppDurations.short4,
          curve: spring,
          child: AdaptiveSurface(
            role: GlassRole.navigation,
            radius: _height / 2,
            // Over true-black dark backgrounds clear glass vanishes; a faint
            // lift keeps the capsule paired with the Add button.
            child: Theme.of(context).brightness == Brightness.dark
                ? ColoredBox(
                    color: Colors.white.withValues(alpha: .08),
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    );
  }
}
