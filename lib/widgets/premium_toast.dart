import 'dart:async';

import 'package:flutter/material.dart';

import '../core/navigation/root_navigator.dart';
import '../core/theme/app_theme.dart';
import '../models/auth_user.dart';
import 'fab_anchor.dart';
import 'adaptive_surface.dart';
import 'profile_avatar.dart';

const double _kAvatarSize = 36;

OverlayEntry? _activePremiumToast;
int _toastGeneration = 0;

/// Also invalidates confirmations queued before an authorization route opened.
void dismissPremiumToast() {
  _toastGeneration++;
  _activePremiumToast?.remove();
  _activePremiumToast = null;
}

void showPremiumToast(
  BuildContext context, {
  required String message,
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
    icon: icon,
    avatarUser: avatarUser,
    duration: duration,
  );
}

void showAppPremiumToast({
  required String message,
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
  IconData? icon,
  AuthUser? avatarUser,
  required Duration duration,
}) {
  _activePremiumToast?.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PremiumToastOverlay(
      message: message,
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
    required this.icon,
    required this.avatarUser,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
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
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.medium2,
      reverseDuration: AppDurations.short4,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppEasing.emphasizedDecelerate,
      reverseCurve: AppEasing.emphasizedAccelerate,
    );
    _opacity = curved;
    _scale = Tween<double>(begin: .96, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: const Offset(0, .18),
      end: Offset.zero,
    ).animate(curved);

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
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _controller.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
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
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _offset,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.bottomCenter,
                  child: _PremiumToastCard(
                    key: const ValueKey('premium-toast-card'),
                    message: widget.message,
                    icon: widget.icon,
                    avatarUser: widget.avatarUser,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumToastCard extends StatelessWidget {
  const _PremiumToastCard({
    super.key,
    required this.message,
    required this.icon,
    required this.avatarUser,
  });

  final String message;
  final IconData? icon;
  final AuthUser? avatarUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final content = Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Leading(icon: icon, avatarUser: avatarUser),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ios ? scheme.onSurface : scheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: ios
          ? AdaptiveSurface(
              radius: 28,
              role: GlassRole.navigation,
              child: ColoredBox(
                // Keep text legible over busy file thumbnails.
                color: scheme.surfaceContainerHigh.withValues(alpha: .85),
                child: content,
              ),
            )
          : Material(
              color: scheme.inverseSurface,
              elevation: AppElevation.level3,
              borderRadius: AppRadii.mdR,
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.icon, required this.avatarUser});

  final IconData? icon;
  final AuthUser? avatarUser;

  @override
  Widget build(BuildContext context) {
    if (avatarUser != null) {
      return ProfileAvatar(user: avatarUser, size: _kAvatarSize);
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _kAvatarSize,
      height: _kAvatarSize,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onSecondaryContainer, size: 20),
    );
  }
}
