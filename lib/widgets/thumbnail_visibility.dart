import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/media/thumbnail_scheduler.dart';

/// Measures the actual painted viewport, including nested scroll views. Built
/// sliver cache children are nearby, not visible; inactive tabs do no work.
class ThumbnailVisibility extends StatefulWidget {
  const ThumbnailVisibility({
    required this.onChanged,
    required this.child,
    super.key,
  });
  final ValueChanged<ThumbnailPriority?> onChanged;
  final Widget child;

  @override
  State<ThumbnailVisibility> createState() => _ThumbnailVisibilityState();
}

class _ThumbnailVisibilityState extends State<ThumbnailVisibility>
    with WidgetsBindingObserver {
  final _positions = <ScrollPosition>{};
  bool _pending = false;
  bool _active = true;
  bool _foreground = true;
  ThumbnailPriority? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    for (final position in _positions) {
      position.removeListener(_schedule);
    }
    _positions.clear();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        _positions.add((element.state as ScrollableState).position);
      }
      return true;
    });
    for (final position in _positions) {
      position.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      // Paused apps do not produce frames; release requests immediately.
      if (_last != null) {
        _last = null;
        widget.onChanged(null);
      }
      return;
    }
    _schedule();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _schedule() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      final priority = _measure();
      if (_last == priority) return;
      _last = priority;
      widget.onChanged(priority);
    });
  }

  ThumbnailPriority? _measure() {
    if (!_active || !_foreground) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    if (bounds.isEmpty) return null;
    var visible = Offset.zero & MediaQuery.sizeOf(context);
    var nearby = visible;
    RenderObject? ancestor = box.parent;
    while (ancestor != null) {
      if (ancestor is RenderOffstage && ancestor.offstage) return null;
      if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
        final viewport = ancestor as RenderBox;
        final rect = viewport.localToGlobal(Offset.zero) & viewport.size;
        visible = visible.intersect(rect);
        nearby = nearby.intersect(rect.inflate(200));
      }
      ancestor = ancestor.parent;
    }
    if (!visible.isEmpty && visible.overlaps(bounds)) {
      return ThumbnailPriority.visible;
    }
    if (!nearby.isEmpty && nearby.overlaps(bounds)) {
      return ThumbnailPriority.nearby;
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final position in _positions) {
      position.removeListener(_schedule);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LayoutObserver(onLayout: _schedule, child: widget.child);
}

class _LayoutObserver extends SingleChildRenderObjectWidget {
  const _LayoutObserver({required this.onLayout, required super.child});
  final VoidCallback onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LayoutObserverBox(onLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    _LayoutObserverBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
  }
}

class _LayoutObserverBox extends RenderProxyBox {
  _LayoutObserverBox(this.onLayout);
  VoidCallback onLayout;
  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
