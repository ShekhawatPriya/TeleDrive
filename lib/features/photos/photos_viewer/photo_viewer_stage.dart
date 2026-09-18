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
    this.mediaZoomed = false,
  });
  final Widget media, header, footer;
  final double? mediaAspectRatio;
  final bool mediaZoomed;
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
  double _height = 1;
  bool _draggingMedia = false;
  Widget? _detailsContent;
  ScrollController? _detailsScroll;
  double _extent = 0;
  static const _peekExtent = .55;
  double _maxExtent = .94;
  bool get isOpen => _extent > .001;
  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (_controller.isAttached)
          _controller.jumpTo(_motion.value.clamp(0, _maxExtent));
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

  void _beginDrag(DragStartDetails _) {
    _draggingMedia = true;
    _motion.stop();
    // Cancel sheet-owned inertia before handing ownership to the handle/media.
    if (_controller.isAttached) _controller.jumpTo(_extent);
  }

  void _drag(DragUpdateDetails details) {
    if (!_controller.isAttached) return;
    _controller.jumpTo(
      (_extent - details.delta.dy / _height).clamp(0, _maxExtent),
    );
  }

  void _endDrag(DragEndDetails details) {
    _draggingMedia = false;
    final velocity = -(details.primaryVelocity ?? 0);
    if (_extent * _height < 12 && velocity <= 0) {
      _settle(0);
    } else if (velocity.abs() >= 50 &&
        !MediaQuery.disableAnimationsOf(context)) {
      _target = _extent;
      _motion.animateWith(
        _InspectorInertia(
          ClampingScrollSimulation(
            position: _extent * _height,
            velocity: velocity,
          ),
          height: _height,
          maxExtent: _maxExtent,
        ),
      );
    }
    // A slow release stays where the user put it. There is no middle snap trap.
  }

  void _cancelDrag() {
    if (!_draggingMedia) return;
    _draggingMedia = false;
    if (_extent * _height < 12) _settle(0);
  }

  @override
  void didUpdateWidget(covariant PhotoViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _detailsContent = null;
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
        _height = bounds.maxHeight;
        final ratio = widget.mediaAspectRatio;
        final imageHeight = ratio == null || ratio <= 0
            ? bounds.maxHeight
            : math.min(bounds.maxHeight, bounds.maxWidth / ratio);
        // Detents belong to the viewport, never to an image's dimensions.
        // Keep the decoded PhotoView layout stable and transform its paint only.
        final safeTop = MediaQuery.paddingOf(context).top;
        _maxExtent = (1 - (safeTop + 12) / bounds.maxHeight).clamp(.55, .94);
        final panelTop = bounds.maxHeight * (1 - _extent);
        final topInset = safeTop * (_extent / _peekExtent).clamp(0, 1);
        final available = math.max(0.0, panelTop - topInset);
        final mediaScale = math.min(1.0, available / imageHeight);
        final mediaCenter = math.min(
          bounds.maxHeight / 2,
          panelTop - imageHeight * mediaScale / 2,
        );
        final mediaOffset = mediaCenter - bounds.maxHeight / 2;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: widget.mediaZoomed ? null : _beginDrag,
                onVerticalDragUpdate: widget.mediaZoomed ? null : _drag,
                onVerticalDragCancel: widget.mediaZoomed ? null : _cancelDrag,
                onVerticalDragEnd: widget.mediaZoomed ? null : _endDrag,
                child: Transform.translate(
                  offset: Offset(0, mediaOffset),
                  child: Transform.scale(
                    key: const ValueKey('viewer-media-transform'),
                    scale: mediaScale,
                    child: RepaintBoundary(child: widget.media),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: isOpen,
                child: ExcludeSemantics(
                  excluding: isOpen,
                  child: Opacity(
                    opacity: (1 - _extent / .25).clamp(0, 1),
                    child: widget.header,
                  ),
                ),
              ),
            ),
            DraggableScrollableSheet(
              controller: _controller,
              initialChildSize: 0,
              minChildSize: 0,
              maxChildSize: _maxExtent,
              snap: false,
              shouldCloseOnMinExtent: false,
              builder: (context, scroll) {
                _detailsScroll = scroll;
                return Listener(
                  onPointerDown: (_) => _motion.stop(),
                  child: ColoredBox(
                    key: const ValueKey('viewer-details-surface'),
                    color: Theme.of(context).colorScheme.surface,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Column(
                        children: [
                          SizedBox(
                            height: math.min(44, constraints.maxHeight),
                            child: Semantics(
                              label: 'Resize photo information',
                              onIncrease: () => _settle(_maxExtent),
                              onDecrease: () => _settle(0),
                              child: GestureDetector(
                                key: const ValueKey('viewer-details-handle'),
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: _beginDrag,
                                onVerticalDragUpdate: _drag,
                                onVerticalDragEnd: _endDrag,
                                onVerticalDragCancel: _cancelDrag,
                                child: Center(
                                  child: Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .4),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _detailsContent ??= widget.detailsBuilder(
                              scroll,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

/// Keep the same pixel-based ballistic motion as the scroll view, while the
/// stage controller stores a viewport fraction. Stop at either physical edge.
class _InspectorInertia extends Simulation {
  _InspectorInertia(
    this.scroll, {
    required this.height,
    required this.maxExtent,
  });
  final Simulation scroll;
  final double height, maxExtent;
  @override
  double x(double time) => (scroll.x(time) / height).clamp(0, maxExtent);
  @override
  double dx(double time) => scroll.dx(time) / height;
  @override
  bool isDone(double time) =>
      scroll.isDone(time) ||
      (time > 0 &&
          (scroll.x(time) <= 0 || scroll.x(time) >= maxExtent * height));
}
