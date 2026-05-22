import 'dart:async';

import 'package:flutter/material.dart';

import '../core/navigation/root_navigator.dart';
import '../core/theme/app_theme.dart';
import '../models/auth_user.dart';
import 'fab_anchor.dart';
import 'profile_avatar.dart';

const double _kFabSize = 56;
const double _kAvatarSize = 36;

OverlayEntry? _activePremiumToast;

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
}) {
  assert(
    icon != null || avatarUser != null,
    'showAppPremiumToast needs either an icon or an avatarUser.',
  );

  void run() {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[PremiumToast] rootNavigatorKey.currentState?.overlay is null.');
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
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: fabAnchorBottom,
      builder: (context, anchor, _) {
        final fallback =
            MediaQuery.paddingOf(context).bottom + AppSpacing.md;
        final bottom = anchor > 0 ? anchor : fallback;
        return Positioned(
          bottom: bottom,
          left: AppSpacing.md,
          right: AppSpacing.md + _kFabSize + AppSpacing.sm,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _offset,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.bottomLeft,
                  child: _PremiumToastCard(
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
    final brightness = theme.brightness;

    return Material(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: scheme.shadow,
      elevation: AppElevation.level3,
      borderRadius: AppRadii.lgR,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.lgR,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .64),
          ),
          boxShadow: AppElevation.shadowFor(AppElevation.level3, brightness),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kFabSize),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Leading(icon: icon, avatarUser: avatarUser),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
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
