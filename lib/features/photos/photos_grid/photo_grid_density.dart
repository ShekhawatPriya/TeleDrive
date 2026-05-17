import 'package:flutter/material.dart';
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

  int get columns => _columns;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_key);
    if (stored != null && stored >= min && stored <= max && stored != _columns) {
      _columns = stored;
      notifyListeners();
    }
  }

  Future<void> set(int next) async {
    final clamped = next.clamp(min, max);
    if (clamped == _columns) return;
    _columns = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _columns);
  }

  void zoomIn() => set(_columns - 1);
  void zoomOut() => set(_columns + 1);
}

class PhotoGridPinchDetector extends StatefulWidget {
  const PhotoGridPinchDetector({
    required this.density,
    required this.child,
    super.key,
  });

  final PhotoGridDensity density;
  final Widget child;

  @override
  State<PhotoGridPinchDetector> createState() => _PhotoGridPinchDetectorState();
}

class _PhotoGridPinchDetectorState extends State<PhotoGridPinchDetector> {
  bool _committed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onScaleStart: (_) => _committed = false,
      onScaleUpdate: (details) {
        if (details.pointerCount < 2 || _committed) return;
        final delta = details.scale - 1;
        if (delta > 0.35) {
          widget.density.zoomIn();
          _committed = true;
        } else if (delta < -0.35) {
          widget.density.zoomOut();
          _committed = true;
        }
      },
      onScaleEnd: (_) => _committed = false,
      child: widget.child,
    );
  }
}
