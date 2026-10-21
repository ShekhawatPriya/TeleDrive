import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/navigation/root_navigator.dart';
import '../core/theme/app_theme.dart';
import '../models/auth_user.dart';
import 'fab_anchor.dart';
import 'adaptive_surface.dart';
import 'ios/ios_browse.dart';
import 'profile_avatar.dart';

const double _kAvatarSize = 36;

// iOS: a glass capsule as tall as the header's 44-point controls. In a tab
// header it sits in the empty leading side of the controls row, so it never
// covers them; elsewhere it is centred under the status bar.
const double _kIosPillHeight = 44;
const double _kIosAvatarSize = 32;
// Concentric with the capsule end: (44 - 32) / 2.
const double _kIosAvatarInset = (_kIosPillHeight - _kIosAvatarSize) / 2;
const double _kIosAvatarGap = 10;
const double _kIosTextInset = 5;
const double _kIosTrailingInset = 16;
const double _kIosMaxWidth = 420;
// Below this span beside the controls (small phones with large text), the
// pill takes its own row under them instead of wrapping into a tall column.
const double _kIosMinHeaderSpan = 168;

final _headerAnchors = <_PremiumToastHeaderAnchorState>{};

/// Marks a header's trailing controls so the iOS toast can sit in the empty
/// space beside them instead of covering them.
class PremiumToastHeaderAnchor extends StatefulWidget {
  const PremiumToastHeaderAnchor({required this.child, super.key});

  final Widget child;

  @override
  State<PremiumToastHeaderAnchor> createState() =>
      _PremiumToastHeaderAnchorState();
}

class _PremiumToastHeaderAnchorState extends State<PremiumToastHeaderAnchor> {
  bool Function() _isVisible = () => true;

  @override
  void initState() {
    super.initState();
    _headerAnchors.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hidden shell tabs stay mounted with tickers off; covered routes are not
    // current. Neither may place the toast.
    final route = ModalRoute.of(context);
    final ticker = TickerMode.getValuesNotifier(context);
    _isVisible = () => route?.isCurrent != false && ticker.value.enabled;
  }

  @override
  void dispose() {
    _headerAnchors.remove(this);
    super.dispose();
  }

  Rect? get _visibleRect {
    if (!mounted || !_isVisible()) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Rect? _visibleHeaderControls() {
  for (final anchor in _headerAnchors) {
    final rect = anchor._visibleRect;
    if (rect != null) return rect;
  }
  return null;
}

OverlayEntry? _activePremiumToast;
int _toastGeneration = 0;

/// Also invalidates confirmations queued before an authorization route opened.
void dismissPremiumToast() {
  _toastGeneration++;
  _activePremiumToast?.remove();
  _activePremiumToast = null;
}

/// [headline] is an optional bold first line, such as an account name, with
/// [message] beneath it as secondary text.
void showPremiumToast(
  BuildContext context, {
  required String message,
  String? headline,
  IconData? icon,
  AuthUser? avatarUser,
  Duration duration = const Duration(milliseconds: 3500),
}) {
  assert(
    icon != null || avatarUser != null,
    'showPremiumToast needs either an icon or an avatarUser.',
  );

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    debugPrint('[PremiumToast] No Overlay found for provided BuildContext.');
    return;
  }

  _insertPremiumToast(
    overlay,
    message: message,
    headline: headline,
    icon: icon,
    avatarUser: avatarUser,
    duration: duration,
  );
}

void showAppPremiumToast({
  required String message,
  String? headline,
  IconData? icon,
  AuthUser? avatarUser,
  Duration duration = const Duration(milliseconds: 3500),
  bool afterNavigation = false,
  bool Function()? canShow,
}) {
  assert(
    icon != null || avatarUser != null,
    'showAppPremiumToast needs either an icon or an avatarUser.',
  );

  final generation = _toastGeneration;
  void run() {
    if (generation != _toastGeneration || !(canShow?.call() ?? true)) return;
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint(
        '[PremiumToast] rootNavigatorKey.currentState?.overlay is null.',
      );
      return;
    }

    _insertPremiumToast(
      overlay,
      message: message,
      headline: headline,
      icon: icon,
      avatarUser: avatarUser,
      duration: duration,
    );
  }

  if (afterNavigation) {
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  } else {
    run();
  }
}

void _insertPremiumToast(
  OverlayState overlay, {
  required String message,
  String? headline,
  IconData? icon,
  AuthUser? avatarUser,
  required Duration duration,
}) {
  _activePremiumToast?.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PremiumToastOverlay(
      message: message,
      headline: headline,
      icon: icon,
      avatarUser: avatarUser,
      duration: duration,
      onDismissed: () {
        if (identical(_activePremiumToast, entry)) {
          _activePremiumToast = null;
        }
        entry.remove();
      },
    ),
  );

  _activePremiumToast = entry;
  overlay.insert(entry);
}

class _PremiumToastOverlay extends StatefulWidget {
  const _PremiumToastOverlay({
    required this.message,
    required this.headline,
    required this.icon,
    required this.avatarUser,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final String? headline;
  final IconData? icon;
  final AuthUser? avatarUser;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_PremiumToastOverlay> createState() => _PremiumToastOverlayState();
}

class _PremiumToastOverlayState extends State<_PremiumToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  late final Animation<double> _scale;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    _controller = AnimationController(
      vsync: this,
      duration: ios ? AppDurations.long1 : AppDurations.medium2,
      reverseDuration: AppDurations.short4,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: ios ? AdaptiveEasing.iosSpring : AppEasing.emphasizedDecelerate,
      reverseCurve: AppEasing.emphasizedAccelerate,
    );
    _scale = Tween<double>(begin: .96, end: 1).animate(_curved);

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _controller.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  Widget _animated({
    required bool fromTop,
    required Widget child,
    Alignment? origin,
  }) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, fromTop ? -.5 : .18),
          end: Offset.zero,
        ).animate(_curved),
        child: ScaleTransition(
          scale: _scale,
          alignment:
              origin ??
              (fromTop ? Alignment.topCenter : Alignment.bottomCenter),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _PremiumToastCard(
      key: const ValueKey('premium-toast-card'),
      message: widget.message,
      headline: widget.headline,
      icon: widget.icon,
      avatarUser: widget.avatarUser,
    );
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _buildIos(context, card);
    }
    return _buildAndroid(context, card);
  }

  Rect? _controls;
  int _anchorChecks = 0;

  /// Rechecks the header for a few frames: after a navigation the tab header
  /// may lay out only after the toast is first built.
  void _trackControls() {
    if (_anchorChecks++ > 12) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controls = _visibleHeaderControls();
      if (controls != _controls) setState(() => _controls = controls);
      _trackControls();
    });
  }

  /// In a tab header the pill fills the empty leading side of the controls
  /// row, aligned with the title's 20-point gutter and 8 points before the
  /// controls (their own spacing). Without a header it is centred under the
  /// status bar or Dynamic Island. A swipe up or tap dismisses it.
  Widget _buildIos(BuildContext context, Widget card) {
    final media = MediaQuery.of(context);
    if (_anchorChecks == 0) {
      _controls = _visibleHeaderControls();
      _trackControls();
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final start = rtl ? Alignment.topRight : Alignment.topLeft;

    Widget pill(Alignment alignment) => Align(
      alignment: alignment,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kIosMaxWidth),
        child: GestureDetector(
          onTap: _dismiss,
          onVerticalDragUpdate: (details) {
            if (details.delta.dy < 0) _dismiss();
          },
          child: _animated(fromTop: true, origin: alignment, child: card),
        ),
      ),
    );

    final controls = _controls;
    if (controls != null) {
      final width = media.size.width;
      const gutter = IosBrowse.gutter;
      final beside = rtl
          ? width - controls.right - AppSpacing.xs - gutter
          : controls.left - AppSpacing.xs - gutter;
      final largeText = media.textScaler.scale(1) > 1.35;
      if (beside >= _kIosMinHeaderSpan && !largeText) {
        return Positioned(
          top: controls.center.dy - _kIosPillHeight / 2,
          left: rtl ? width - gutter - beside : gutter,
          right: rtl ? gutter : width - gutter - beside,
          child: pill(start),
        );
      }
      return Positioned(
        top: controls.bottom + AppSpacing.xs,
        left: gutter,
        right: gutter,
        child: pill(start),
      );
    }
    return Positioned(
      top: math.max(media.padding.top, AppSpacing.md) + AppSpacing.xxs,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: pill(Alignment.topCenter),
    );
  }

  /// Material snackbar placement: bottom row beside Add, filling the span.
  Widget _buildAndroid(BuildContext context, Widget card) {
    return ValueListenableBuilder<({double bottom, double reservedWidth})?>(
      valueListenable: fabAnchor,
      builder: (context, anchor, _) {
        final media = MediaQuery.of(context);
        final fallback = media.padding.bottom + AppSpacing.md;
        final bottom = media.viewInsets.bottom > 0
            ? media.viewInsets.bottom + AppSpacing.md
            : anchor?.bottom ?? fallback;
        final reserved = media.viewInsets.bottom == 0
            ? anchor?.reservedWidth ?? 0.0
            : 0.0;
        return Positioned(
          bottom: bottom,
          left: AppSpacing.md,
          right: AppSpacing.md + (reserved > 0 ? reserved + AppSpacing.sm : 0),
          child: IgnorePointer(child: _animated(fromTop: false, child: card)),
        );
      },
    );
  }
}

class _PremiumToastCard extends StatelessWidget {
  const _PremiumToastCard({
    super.key,
    required this.message,
    required this.headline,
    required this.icon,
    required this.avatarUser,
  });

  final String message;
  final String? headline;
  final IconData? icon;
  final AuthUser? avatarUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final label = headline == null ? message : '$headline. $message';
    if (!ios) {
      return Semantics(
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: scheme.inverseSurface,
          elevation: AppElevation.level3,
          borderRadius: AppRadii.mdR,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Leading(icon: icon, avatarUser: avatarUser),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToastText(
                    message: message,
                    headline: headline,
                    color: scheme.onInverseSurface,
                    secondaryColor: scheme.onInverseSurface.withValues(
                      alpha: .78,
                    ),
                    ios: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: AdaptiveSurface(
          radius: _kIosPillHeight / 2,
          role: GlassRole.navigation,
          child: ColoredBox(
            // Keep text legible over busy file thumbnails.
            color: scheme.surfaceContainerHigh.withValues(alpha: .85),
            child: Padding(
              // The avatar is concentric with the capsule end; text has no
              // curve of its own, so its end gets a wider optical inset.
              // Two text lines (34 points) set the row, leaving 5 points
              // above and below and centring the avatar 6 points from each
              // edge of the 44-point capsule.
              padding: const EdgeInsetsDirectional.fromSTEB(
                _kIosAvatarInset,
                _kIosTextInset,
                _kIosTrailingInset,
                _kIosTextInset,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Leading(
                    icon: icon,
                    avatarUser: avatarUser,
                    size: _kIosAvatarSize,
                  ),
                  const SizedBox(width: _kIosAvatarGap),
                  // Text sits beside the avatar and the pill hugs it, so
                  // every name keeps the same internal spacing.
                  Flexible(
                    child: _ToastText(
                      message: message,
                      headline: headline,
                      color: scheme.onSurface,
                      secondaryColor: scheme.onSurfaceVariant,
                      ios: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps without a line limit; wrapped lines shrink to the longest one so a
/// long name does not leave a gap after its last word.
class _ToastText extends StatelessWidget {
  const _ToastText({
    required this.message,
    required this.headline,
    required this.color,
    required this.secondaryColor,
    required this.ios,
  });

  final String message;
  final String? headline;
  final Color color;
  final Color secondaryColor;
  final bool ios;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const align = TextAlign.start;
    // Two lines fit the 44-point capsule: 18 + 16 points of line height.
    final primary = ios
        ? IosBrowse.subheadline(
            context,
            weight: FontWeight.w600,
          ).copyWith(height: 18 / 15)
        : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    if (headline == null) {
      return Text(
        message,
        textAlign: align,
        textWidthBasis: TextWidthBasis.longestLine,
        style: primary?.copyWith(color: color, height: ios ? null : 1.3),
      );
    }
    final secondary = ios
        ? IosBrowse.footnote(
            context,
            color: secondaryColor,
          ).copyWith(height: 16 / 13)
        : textTheme.bodySmall?.copyWith(color: secondaryColor);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline!,
          textAlign: align,
          textWidthBasis: TextWidthBasis.longestLine,
          style: primary?.copyWith(color: color),
        ),
        Text(
          message,
          textAlign: align,
          textWidthBasis: TextWidthBasis.longestLine,
          style: secondary,
        ),
      ],
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.icon,
    required this.avatarUser,
    this.size = _kAvatarSize,
  });

  final IconData? icon;
  final AuthUser? avatarUser;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUser != null) {
      return ProfileAvatar(user: avatarUser, size: size);
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onSecondaryContainer, size: size * .55),
    );
  }
}
