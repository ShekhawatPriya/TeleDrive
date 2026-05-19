import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

OverlayEntry? _activePremiumToast;

void showPremiumToast(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(milliseconds: 3500),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  _activePremiumToast?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PremiumToastOverlay(
      title: title,
      message: message,
      icon: icon,
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
    required this.title,
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  final String title;
  final String message;
  final IconData icon;
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
      begin: const Offset(0, -.16),
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
    return Positioned(
      top: 0,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _offset,
                child: ScaleTransition(
                  scale: _scale,
                  child: _PremiumToastCard(
                    title: widget.title,
                    message: widget.message,
                    icon: widget.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumToastCard extends StatelessWidget {
  const _PremiumToastCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
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
              boxShadow: AppElevation.shadowFor(
                AppElevation.level3,
                brightness,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: AppColors.warning, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
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
