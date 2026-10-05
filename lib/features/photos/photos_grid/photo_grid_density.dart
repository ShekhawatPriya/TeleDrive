import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoGridDensity extends ChangeNotifier {
  PhotoGridDensity({this.min = 2, this.max = 5, int initial = 3})
    : _columns = initial.clamp(min, max) {
    _load();
  }

  static const _key = 'teledrive_photos_columns';

  final int min;
  final int max;
  int _columns;
  bool _disposed = false;
  int _revision = 0;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  int get columns => _columns;

  Future<void> _load() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;
    final stored = prefs.getInt(_key);
    if (stored != null &&
        stored >= min &&
        stored <= max &&
        stored != _columns) {
      _columns = stored;
      notifyListeners();
    }
  }

  Future<void> set(int next) async {
    final clamped = next.clamp(min, max);
    if (clamped == _columns) return;
    _revision++;
    _columns = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _columns);
  }

  void zoomIn() => set(_columns - 1);
  void zoomOut() => set(_columns + 1);
}

final photoGridDensityProvider = ChangeNotifierProvider<PhotoGridDensity>((
  ref,
) {
  final density = PhotoGridDensity();
  return density;
});

/// Pointer observation leaves one-finger scrolling out of the scale arena.
/// A regular ScaleGestureRecognizer can win a vertical drag before a second
/// finger arrives, which makes gallery flings feel as though they get stuck.
class PhotoGridPinchDetector extends StatefulWidget {
  const PhotoGridPinchDetector({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
    super.key,
  });
  final ValueChanged<Offset> onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;
  final Widget child;
  @override
  State<PhotoGridPinchDetector> createState() => _PhotoGridPinchDetectorState();
}

class _PhotoGridPinchDetectorState extends State<PhotoGridPinchDetector> {
  final _pointers = <int, Offset>{};
  double? _initialDistance;
  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final points = _pointers.values.toList();
      _initialDistance = (points[0] - points[1]).distance;
      widget.onStart((points[0] + points[1]) / 2);
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final initial = _initialDistance;
    if (initial == null || initial <= 0 || _pointers.length < 2) return;
    final points = _pointers.values.take(2).toList();
    widget.onUpdate((points[0] - points[1]).distance / initial);
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _initialDistance != null) {
      _initialDistance = null;
      widget.onEnd();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.child,
  );
}
