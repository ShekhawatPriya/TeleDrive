import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A nonmodal inspector: media and information share one continuous surface.
class PhotoViewerStage extends StatefulWidget {
  const PhotoViewerStage({
    super.key,
    required this.media,
    required this.header,
    required this.footer,
    required this.detailsBuilder,
    required this.onDetailsChanged,
    this.mediaAspectRatio,
  });
  final Widget media, header, footer;
  final double? mediaAspectRatio;
  final Widget Function(ScrollController) detailsBuilder;
  final VoidCallback onDetailsChanged;
  @override
  State<PhotoViewerStage> createState() => PhotoViewerStageState();
}

class PhotoViewerStageState extends State<PhotoViewerStage>
    with SingleTickerProviderStateMixin {
  final _controller = DraggableScrollableController();
  late final AnimationController _motion;
  double _target = 0;
  ScrollController? _detailsScroll;
  double _extent = 0;
  double _peekExtent = .55;
  bool get isOpen => _extent > .05;
  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (_controller.isAttached)
          _controller.jumpTo(_motion.value.clamp(0, .94));
      });
    _controller.addListener(_changed);
  }

  void _changed() {
    final wasOpen = isOpen;
    setState(() => _extent = _controller.size);
    if (wasOpen != isOpen) widget.onDetailsChanged();
  }

  void toggle() =>
      _settle((_motion.isAnimating ? _target > 0 : isOpen) ? 0 : _peekExtent);
  void _settle(double value, {double? velocity}) {
    if (!_controller.isAttached) return;
    _target = value;
    final speed = velocity ?? (_motion.isAnimating ? _motion.velocity : 0);
    _motion.stop();
    if (value == 0 && (_detailsScroll?.hasClients ?? false))
      _detailsScroll!.jumpTo(0);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(value);
    } else {
      _motion.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: 350, ratio: 1),
          _extent,
          value,
          speed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !isOpen,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _settle(0);
    },
    child: LayoutBuilder(
      builder: (context, bounds) {
        final ratio = widget.mediaAspectRatio;
        final imageHeight = ratio == null || ratio <= 0
            ? bounds.maxHeight
            : math.min(bounds.maxHeight, bounds.maxWidth / ratio);
        _peekExtent =
            (1 -
                    math.min(imageHeight, bounds.maxHeight * .45) /
                        bounds.maxHeight)
                .clamp(.55, .90);
        // Consume the lower letterbox first. Once the inspector reaches the
        // visible image, their edges travel together without an empty gap.
        final lowerLetterbox = (bounds.maxHeight - imageHeight) / 2;
        final mediaOffset = -math.max(
          0.0,
          bounds.maxHeight * _extent - lowerLetterbox,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (_) => _motion.stop(),
                onVerticalDragUpdate: (d) {
                  if (_controller.isAttached)
                    _controller.jumpTo(
                      (_extent - d.delta.dy / bounds.maxHeight).clamp(0, .94),
                    );
                },
                onVerticalDragEnd: (d) {
                  final projected =
                      _extent -
                      (d.primaryVelocity ?? 0) / bounds.maxHeight * .15;
                  _settle(
                    projected < .18
                        ? 0
                        : projected > (_peekExtent + .94) / 2
                        ? .94
                        : _peekExtent,
                    velocity: -(d.primaryVelocity ?? 0) / bounds.maxHeight,
                  );
                },
                child: Transform.translate(
                  offset: Offset(0, mediaOffset),
                  child: widget.media,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: isOpen,
                child: Opacity(
                  opacity: (1 - _extent / .25).clamp(0, 1),
                  child: widget.header,
                ),
              ),
            ),
            DraggableScrollableSheet(
              controller: _controller,
              initialChildSize: 0,
              minChildSize: 0,
              maxChildSize: .94,
              snap: true,
              snapSizes: [_peekExtent],
              shouldCloseOnMinExtent: false,
              builder: (context, scroll) {
                _detailsScroll = scroll;
                return Listener(
                  onPointerDown: (_) => _motion.stop(),
                  child: widget.detailsBuilder(scroll),
                );
              },
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: widget.footer),
          ],
        );
      },
    ),
  );
}
