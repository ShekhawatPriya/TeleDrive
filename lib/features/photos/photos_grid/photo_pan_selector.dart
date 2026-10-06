import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Horizontal intent starts selection; subsequent motion can move in any axis.
/// A vertical initial drag continues to scroll the library normally.
class PhotoPanSelector extends StatefulWidget {
  const PhotoPanSelector({
    required this.enabled,
    required this.tileKeys,
    required this.onTilePan,
    required this.child,
    this.onRange,
    this.onStart,
    this.orderedIds = const [],
    this.scrollController,
    super.key,
  });
  final bool enabled;
  final VoidCallback? onStart;
  final Map<String, GlobalKey> tileKeys;
  final ValueChanged<String> onTilePan;
  final void Function(String start, String end)? onRange;
  final List<String> orderedIds;
  final ScrollController? scrollController;
  final Widget child;
  @override
  State<PhotoPanSelector> createState() => _PhotoPanSelectorState();
}

class _PhotoPanSelectorState extends State<PhotoPanSelector>
    with SingleTickerProviderStateMixin {
  String? _start, _last;
  Offset? _pointer;
  late final Ticker _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  Duration _lastTick = Duration.zero;
  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    final scroll = widget.scrollController;
    final box = context.findRenderObject();
    if (_pointer == null ||
        scroll == null ||
        !scroll.hasClients ||
        box is! RenderBox)
      return;
    final y = box.globalToLocal(_pointer!).dy;
    final velocity = y < 64
        ? -((64 - y) / 64).clamp(0, 1) * 600
        : y > box.size.height - 64
        ? ((y - box.size.height + 64) / 64).clamp(0, 1) * 600
        : 0.0;
    if (velocity == 0) return;
    scroll.jumpTo(
      (scroll.offset + velocity * dt.clamp(0, .05)).clamp(
        scroll.position.minScrollExtent,
        scroll.position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hit();
    });
  }

  void _hit() {
    if (_pointer == null) return;
    // Visit instantiated tile keys rather than the loaded collection.
    for (final entry in widget.tileKeys.entries) {
      final id = entry.key;
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (!(box.localToGlobal(Offset.zero) & box.size).contains(_pointer!))
        continue;
      _start ??= id;
      if (_last == id) return;
      _last = id;
      if (widget.onRange != null) {
        widget.onRange!(_start!, id);
      } else {
        widget.onTilePan(id);
      }
      return;
    }
  }

  void _end() {
    _ticker.stop();
    _pointer = null;
    _start = null;
    _last = null;
  }

  @override
  void didUpdateWidget(PhotoPanSelector old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _end();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.enabled
      ? widget.child
      : RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  HorizontalDragGestureRecognizer
                >(() => HorizontalDragGestureRecognizer(), (g) {
                  g
                    ..onStart = (d) {
                      widget.onStart?.call();
                      _pointer = d.globalPosition;
                      _lastTick = Duration.zero;
                      _hit();
                      _ticker.start();
                    }
                    ..onUpdate = (d) {
                      _pointer = d.globalPosition;
                      _hit();
                    }
                    ..onEnd = (_) {
                      _end();
                    }
                    ..onCancel = _end;
                }),
          },
          child: widget.child,
        );
}
