import 'package:flutter/widgets.dart';

/// Screen-space position of the floating action row and the width reserved for
/// its visible Add button. A row without Add retains its vertical anchor.
final fabAnchor = ValueNotifier<({double bottom, double reservedWidth})?>(null);
Object? _anchorOwner;

/// Measures the row and optional Add button after layout.
class FabAnchorPublisher extends StatefulWidget {
  const FabAnchorPublisher({required this.child, this.fabKey, super.key});

  final GlobalKey? fabKey;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_anchorOwner, this)) {
        _anchorOwner = null;
        fabAnchor.value = null;
      }
    });
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
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final boxBottomGlobal = renderObject
        .localToGlobal(Offset(0, renderObject.size.height))
        .dy;
    final fromScreenBottom = screenHeight - boxBottomGlobal;
    if (fromScreenBottom < 0) return;
    final fab = widget.fabKey?.currentContext?.findRenderObject();
    final width = fab is RenderBox && fab.hasSize ? fab.size.width : 0.0;
    _anchorOwner = this;
    fabAnchor.value = (bottom: fromScreenBottom, reservedWidth: width);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return KeyedSubtree(key: _measureKey, child: widget.child);
  }
}
