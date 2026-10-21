import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/adaptive_surface.dart';
import 'upload_status_ring.dart';

/// The one floating status control beside Add, shared by every background
/// operation (uploads, deletes) so they always look and move alike.
///
/// iOS: a 60-point glass capsule in the anatomy of Apple's floating
/// mini-player — leading status disc with a progress ring, two lines of text,
/// one trailing accent. Android: a Material surface with the same content.
/// With [onTap] the capsule is a button (and on iOS also expands on an upward
/// drag); without it the capsule only reports status.
class StatusCapsule extends StatelessWidget {
  const StatusCapsule({
    required this.title,
    required this.detail,
    required this.tint,
    required this.icon,
    required this.materialIcon,
    required this.semanticLabel,
    this.progress,
    this.trailing,
    this.attention = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String detail;

  /// Short accent after the text, e.g. a percentage or "Review".
  final String? trailing;

  /// Status colour (iOS disc, ring and accent).
  final Color tint;
  final IconData icon;
  final IconData materialIcon;

  /// Determinate progress for the ring, or null when nothing is moving.
  final double? progress;

  /// Android renders the icon in the error colour.
  final bool attention;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Semantics(
      button: onTap != null,
      liveRegion: onTap == null,
      onTap: onTap,
      label: semanticLabel,
      excludeSemantics: true,
      child: ios ? _IosStatusCapsule(capsule: this) : _MaterialCapsule(this),
    );
  }
}

class _MaterialCapsule extends StatelessWidget {
  const _MaterialCapsule(this.capsule);
  final StatusCapsule capsule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = capsule.progress;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.outlineVariant,
                      color: capsule.attention ? scheme.error : scheme.primary,
                    ),
                  ),
                Icon(
                  capsule.materialIcon,
                  size: progress != null ? 16 : 24,
                  color: capsule.attention ? scheme.error : scheme.primary,
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
                Text(capsule.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(capsule.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (capsule.trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              capsule.trailing!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: capsule.attention ? scheme.error : scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (capsule.onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    return Material(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level2,
      borderRadius: AppRadii.xlR,
      clipBehavior: Clip.antiAlias,
      child: capsule.onTap == null
          ? content
          : InkWell(onTap: capsule.onTap, child: content),
    );
  }
}

class _IosStatusCapsule extends StatefulWidget {
  const _IosStatusCapsule({required this.capsule});

  final StatusCapsule capsule;

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
    if (open) widget.capsule.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final tint = capsule.tint;
    final motion = reduced ? Duration.zero : AppDurations.medium2;
    // One line keeps the capsule shape. Enlarged text wraps instead of
    // clipping, and the trailing accent folds into the second line.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final lines = large ? 3 : 1;
    final spring = reduced ? Curves.linear : const IosSpringCurve(damping: .7);
    final trailing = large ? null : capsule.trailing;
    final detail = large && capsule.trailing != null
        ? '${capsule.detail} · ${capsule.trailing}'
        : capsule.detail;

    final disc = UploadStatusRing(
      tint: tint,
      icon: capsule.icon,
      progress: capsule.progress,
      iconSize: 19,
    );
    final text = AnimatedSwitcher(
      duration: motion,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Column(
        key: ValueKey(capsule.title),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capsule.title,
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
                        fontSize: capsule.progress != null ? 17 : 15,
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

    final surface = AdaptiveSurface(
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
    );
    if (capsule.onTap == null) return surface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Measure travel from touch-down so the expand distance is what the
      // finger actually moved, not what remains after touch slop.
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        capsule.onTap?.call();
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
          child: surface,
        ),
      ),
    );
  }
}
