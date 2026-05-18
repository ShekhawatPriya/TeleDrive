import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps the photos grid with a pan-to-select gesture.  Activates only when
/// [enabled] is true (i.e. selection mode is on).  As the pointer crosses
/// tiles tagged with [GlobalObjectKey], [onTilePan] is invoked once per
/// unique id so the host can add them to the selection.  Deliberately uses a
/// horizontal-leaning [PanGestureRecognizer] so that mostly-vertical drags
/// still bubble up to the underlying scroll view.
class PhotoPanSelector extends StatefulWidget {
  const PhotoPanSelector({
    required this.enabled,
    required this.tileKeys,
    required this.onTilePan,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Map<String, GlobalKey> tileKeys;
  final ValueChanged<String> onTilePan;
  final Widget child;

  @override
  State<PhotoPanSelector> createState() => _PhotoPanSelectorState();
}

class _PhotoPanSelectorState extends State<PhotoPanSelector> {
  final Set<String> _hitInThisDrag = {};
  bool _dragging = false;

  void _handleStart(DragStartDetails details) {
    _hitInThisDrag.clear();
    _dragging = true;
    _hitTest(details.globalPosition);
  }

  void _handleUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _hitTest(details.globalPosition);
  }

  void _handleEnd(_) {
    _dragging = false;
    _hitInThisDrag.clear();
  }

  void _hitTest(Offset globalPosition) {
    widget.tileKeys.forEach((id, key) {
      if (_hitInThisDrag.contains(id)) return;
      final renderBox = key.currentContext?.findRenderObject();
      if (renderBox is! RenderBox) return;
      final topLeft = renderBox.localToGlobal(Offset.zero);
      final rect = topLeft & renderBox.size;
      if (rect.contains(globalPosition)) {
        _hitInThisDrag.add(id);
        widget.onTilePan(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (instance) {
            instance
              ..onStart = _handleStart
              ..onUpdate = _handleUpdate
              ..onEnd = _handleEnd
              ..onCancel = () => _handleEnd(null);
          },
        ),
      },
      child: widget.child,
    );
  }
}
