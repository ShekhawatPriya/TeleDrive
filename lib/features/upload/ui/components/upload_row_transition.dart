import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/app_motion.dart';

/// Enter/exit motion for one upload row.
///
/// A row added while the panel is open springs in: its slot opens and the row
/// settles from slightly below at a smaller scale. A departing row slides down
/// while it fades, then its slot closes, and [onExited] lets the list drop it.
/// Reduced motion swaps both for an immediate change.
class UploadRowTransition extends StatefulWidget {
  const UploadRowTransition({
    required this.child,
    this.animateIn = false,
    this.departing = false,
    this.onExited,
    this.onEntered,
    super.key,
  });

  final Widget child;
  final bool animateIn;
  final bool departing;
  final VoidCallback? onExited;
  final VoidCallback? onEntered;

  static const enterDuration = Duration(milliseconds: 560);
  static const exitDuration = Duration(milliseconds: 380);

  @override
  State<UploadRowTransition> createState() => _UploadRowTransitionState();
}

class _UploadRowTransitionState extends State<UploadRowTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: UploadRowTransition.enterDuration,
    reverseDuration: UploadRowTransition.exitDuration,
    value: widget.animateIn && !widget.departing ? 0 : 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.departing) {
      _exit();
    } else if (widget.animateIn) {
      if (_reduceMotion) {
        _controller.value = 1;
        _notifyAfterFrame(widget.onEntered);
      } else {
        _controller.forward().whenCompleteOrCancel(() {
          if (mounted) widget.onEntered?.call();
        });
      }
    }
  }

  @override
  void didUpdateWidget(UploadRowTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.departing && !oldWidget.departing) _exit();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _exit() {
    if (_reduceMotion) {
      _controller.value = 0;
      _notifyAfterFrame(widget.onExited);
      return;
    }
    _controller.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.onExited?.call();
    });
  }

  void _notifyAfterFrame(VoidCallback? callback) {
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    // Forward: the slot opens with a decelerating curve while the row itself
    // springs (a slight overshoot reads as the row landing). Reverse: the row
    // drops and fades first, then the slot closes behind it.
    final size = CurvedAnimation(
      parent: _controller,
      curve: AppEasing.emphasizedDecelerate,
      reverseCurve: const Interval(0, .75, curve: Curves.easeInOutCubic),
    );
    final spring = CurvedAnimation(
      parent: _controller,
      curve: AdaptiveEasing.enter(platform),
      reverseCurve: const Interval(
        .35,
        1,
        curve: AppEasing.emphasizedAccelerate,
      ),
    );
    final opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .5, curve: Curves.easeOut),
      reverseCurve: const Interval(.4, 1, curve: Curves.easeIn),
    );
    return SizeTransition(
      sizeFactor: size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: opacity,
        child: AnimatedBuilder(
          animation: spring,
          child: widget.child,
          builder: (context, child) {
            final t = spring.value;
            final entering = _controller.status != AnimationStatus.reverse;
            return Transform.translate(
              // Enters from 12 points below; departs 24 points downward.
              offset: Offset(0, (1 - t) * (entering ? 12 : 24)),
              child: Transform.scale(
                scale: entering ? .94 + .06 * t : 1,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
