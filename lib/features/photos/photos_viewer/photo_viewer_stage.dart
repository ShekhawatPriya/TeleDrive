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
    this.sourceRect,
    this.prepareDismiss,
    this.onDismissed,
    this.onInteractionChanged,
    this.gesturesEnabled = true,
    this.nativeVideo = false,
  });
  final Widget media, header, footer;
  final double? mediaAspectRatio;
  final bool mediaZoomed;
  final Rect? sourceRect;
  final Future<Rect?> Function()? prepareDismiss;
  final VoidCallback? onDismissed;
  final ValueChanged<bool>? onInteractionChanged;
  final bool gesturesEnabled, nativeVideo;
  final Widget Function(ScrollController) detailsBuilder;
  final VoidCallback onDetailsChanged;
  @override
  State<PhotoViewerStage> createState() => PhotoViewerStageState();
}

class PhotoViewerStageState extends State<PhotoViewerStage>
    with TickerProviderStateMixin {
  final _controller = DraggableScrollableController();
  late final AnimationController _presentation, _recoil;
  Offset _dismissOffset = Offset.zero,
      _dragOrigin = Offset.zero,
      _returnFrom = Offset.zero;
  Offset _exitOffset = Offset.zero;
  double _exitScale = 1, _exitOpacity = 1;
  bool _reversing = false;
  bool _dismissDrag = false,
      _mediaInspectorDrag = false,
      _closing = false,
      _allowPop = false;
  Rect? _destination;
  double get _dismissProgress =>
      (_dismissOffset.dy / (_height * .55)).clamp(0, 1);
  bool get interacting =>
      _dismissDrag ||
      _closing ||
      _presentation.isAnimating ||
      _recoil.isAnimating;

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
    _destination = widget.sourceRect;
    _presentation =
        AnimationController(
          vsync: this,
          value: widget.onDismissed == null ? 1 : 0,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _recoil = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted)
          setState(() => _dismissOffset = _returnFrom * (1 - _recoil.value));
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.onDismissed == null) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _presentation.value = 1;
        widget.onInteractionChanged?.call(false);
      } else {
        _presentation.forward().whenCompleteOrCancel(
          () => widget.onInteractionChanged?.call(false),
        );
      }
    });
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

  void _beginMediaDrag(DragStartDetails details) {
    if (_closing || !widget.gesturesEnabled) return;
    _recoil.stop();
    _dragOrigin = details.globalPosition - _dismissOffset;
    _reversing = false;
    _dismissDrag = _dismissOffset.dy > 0;
    _mediaInspectorDrag = isOpen;
    _beginDrag(details);
  }

  void _moveMedia(DragUpdateDetails details) {
    if (_closing || !widget.gesturesEnabled) return;
    final offset = details.globalPosition - _dragOrigin;
    if (!_mediaInspectorDrag && !_dismissDrag) {
      if (offset.dy > 0 && widget.onDismissed != null) {
        _dismissDrag = true;
        widget.onInteractionChanged?.call(true);
      } else {
        _mediaInspectorDrag = true;
      }
    }
    if (_dismissDrag) {
      if (details.delta.dy.abs() > .5) _reversing = details.delta.dy < 0;
      setState(
        () => _dismissOffset = Offset(offset.dx, math.max(0, offset.dy)),
      );
    } else {
      _drag(details);
    }
  }

  void _endMedia(DragEndDetails details) {
    if (_closing) return;
    if (!_dismissDrag) {
      _endDrag(details);
      return;
    }
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (!_reversing &&
        velocity >= 0 &&
        (_dismissOffset.dy > _height * .22 ||
            (_dismissOffset.dy > 32 && velocity > 900))) {
      dismiss();
    } else {
      _restore(velocity);
    }
  }

  void _restore([double velocity = 0]) {
    _dismissDrag = false;
    _draggingMedia = false;
    _returnFrom = _dismissOffset;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dismissOffset = Offset.zero);
      widget.onInteractionChanged?.call(false);
      return;
    }
    _recoil.value = 0;
    _recoil
        .animateWith(
          SpringSimulation(
            SpringDescription.withDampingRatio(
              mass: 1,
              stiffness: 350,
              ratio: 1,
            ),
            0,
            1,
            -velocity / math.max(1, _returnFrom.distance),
          ),
        )
        .whenCompleteOrCancel(() {
          if (mounted && !_dismissDrag && !_closing) {
            // An asymptotic spring must finish at exact identity. A fractional
            // opacity leaves UIKit platform views in Flutter's offscreen layer.
            setState(() => _dismissOffset = Offset.zero);
            widget.onInteractionChanged?.call(false);
          }
        });
  }

  /// Back, accessibility escape, and interactive dismissal share this path.
  Future<void> dismiss() async {
    if (_closing) return;
    if (isOpen) {
      _settle(0);
      return;
    }
    if (widget.onDismissed == null) {
      Navigator.maybePop(context);
      return;
    }
    _closing = true;
    _recoil.stop();
    widget.onInteractionChanged?.call(true);
    _exitOffset = _dismissOffset;
    _exitScale = 1 - .25 * _dismissProgress;
    _exitOpacity = 1 - _dismissProgress;
    _destination = await widget.prepareDismiss?.call();
    if (!mounted) return;
    _dismissOffset = Offset.zero;
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _presentation
            .animateBack(
              0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            )
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) widget.onDismissed?.call();
  }

  // Native video owns its touch sequence. Only its unclaimed vertical media
  // pans reach this adapter; transport controls never enter Flutter's arena.
  void nativeDrag(String phase, Offset position, Offset velocity) {
    if (widget.mediaZoomed || !widget.gesturesEnabled) return;
    switch (phase) {
      case 'start':
        _beginMediaDrag(DragStartDetails(globalPosition: position));
      case 'update':
        _moveMedia(
          DragUpdateDetails(
            globalPosition: position,
            delta: velocity,
            primaryDelta: velocity.dy,
          ),
        );
      case 'end':
        _endMedia(
          DragEndDetails(
            velocity: Velocity(pixelsPerSecond: velocity),
            primaryVelocity: velocity.dy,
          ),
        );
      default:
        _restore();
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
    _presentation.dispose();
    _recoil.dispose();
    _motion.dispose();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (widget.onDismissed == null && !isOpen),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        if (isOpen) {
          _settle(0);
        } else {
          dismiss();
        }
      }
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
        final t = Curves.easeOutCubic.transform(
          _presentation.value.clamp(0, 1),
        );
        final viewport = Offset.zero & bounds.biggest;
        final render = context.findRenderObject();
        final origin = render is RenderBox && render.hasSize
            ? render.localToGlobal(Offset.zero)
            : Offset.zero;
        final source = _destination?.shift(-origin);
        final fittedWidth = ratio == null
            ? bounds.maxWidth
            : math.min(bounds.maxWidth, bounds.maxHeight * ratio);
        final sourceScale = source == null
            ? 1.0
            : math.max(source.width / fittedWidth, source.height / imageHeight);
        final flightScale =
            sourceScale + ((_closing ? _exitScale : 1) - sourceScale) * t;
        final flightOffset = Offset.lerp(
          source == null ? Offset.zero : source.center - viewport.center,
          _closing ? _exitOffset : Offset.zero,
          t,
        )!;
        final dragScale = 1 - .25 * _dismissProgress;
        final opacity = (_closing ? _exitOpacity : 1 - _dismissProgress) * t;
        final clip = source == null
            ? viewport
            : Rect.lerp(source, viewport, t)!;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                key: const ValueKey('viewer-backdrop'),
                color: Colors.black.withValues(alpha: opacity),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart:
                    widget.mediaZoomed ||
                        widget.nativeVideo ||
                        !widget.gesturesEnabled
                    ? null
                    : _beginMediaDrag,
                onVerticalDragUpdate:
                    widget.mediaZoomed ||
                        widget.nativeVideo ||
                        !widget.gesturesEnabled
                    ? null
                    : _moveMedia,
                onVerticalDragCancel:
                    widget.mediaZoomed ||
                        widget.nativeVideo ||
                        !widget.gesturesEnabled
                    ? null
                    : () {
                        if (_dismissDrag) {
                          _restore();
                        } else {
                          _cancelDrag();
                        }
                      },
                onVerticalDragEnd:
                    widget.mediaZoomed ||
                        widget.nativeVideo ||
                        !widget.gesturesEnabled
                    ? null
                    : _endMedia,
                child: ClipRect(
                  clipper: _MediaClip(clip),
                  child: Opacity(
                    opacity: source == null ? t : 1,
                    child: Transform.translate(
                      offset: flightOffset + _dismissOffset,
                      child: Transform.scale(
                        scale: flightScale * dragScale,
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
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: isOpen || _dismissDrag || _closing,
                child: ExcludeSemantics(
                  excluding: isOpen || _dismissDrag || _closing,
                  child: Opacity(
                    opacity: (1 - _extent / .25).clamp(0, 1) * opacity,
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
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: _dismissDrag || _closing,
                child: ExcludeSemantics(
                  excluding: _dismissDrag || _closing,
                  child: Opacity(opacity: opacity, child: widget.footer),
                ),
              ),
            ),
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

class _MediaClip extends CustomClipper<Rect> {
  const _MediaClip(this.rect);
  final Rect rect;
  @override
  Rect getClip(Size size) => rect;
  @override
  bool shouldReclip(_MediaClip old) => old.rect != rect;
}
