import 'package:flutter/widgets.dart';

/// Distance in logical pixels from the screen's bottom edge to the bottom edge
/// of the currently visible FAB. The bottom-anchored toast pill aligns its own
/// bottom edge to this value so it sits at the same vertical level as the FAB
/// regardless of which screen owns the FAB.
final ValueNotifier<double> fabAnchorBottom = ValueNotifier<double>(0);

/// Wraps a region that owns the FAB and republishes [fabAnchorBottom] after
/// each layout pass by measuring the actual rendered position of [child]. This
/// is robust against route-specific Scaffold layouts that consume safe-area
/// insets in different ways.
class FabAnchorPublisher extends StatefulWidget {
  const FabAnchorPublisher({required this.child, super.key});

  final Widget child;

  @override
  State<FabAnchorPublisher> createState() => _FabAnchorPublisherState();
}

class _FabAnchorPublisherState extends State<FabAnchorPublisher>
    with WidgetsBindingObserver {
  final GlobalKey _measureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMeasure();
  }

  @override
  void didChangeMetrics() {
    _scheduleMeasure();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publish();
    });
  }

  void _publish() {
    final renderObject = _measureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    if (renderObject.size.height <= 0) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final boxBottomGlobal = renderObject
        .localToGlobal(Offset(0, renderObject.size.height))
        .dy;
    final fromScreenBottom = screenHeight - boxBottomGlobal;
    if (fromScreenBottom < 0) return;
    if ((fabAnchorBottom.value - fromScreenBottom).abs() > 0.5) {
      fabAnchorBottom.value = fromScreenBottom;
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return KeyedSubtree(key: _measureKey, child: widget.child);
  }
}
