import 'package:flutter/material.dart';

/// Resolves the global anchor [Rect] for a tile referenced by [tileKey].
/// The overlay box is used as the ancestor coordinate space so any popup
/// route renders at the correct screen location regardless of nested route
/// transitions.
Rect? resolveTileAnchor(GlobalKey tileKey, BuildContext context) {
  final renderObject = tileKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox) return null;
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) return null;
  final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
  return Rect.fromLTWH(
    topLeft.dx,
    topLeft.dy,
    renderObject.size.width,
    renderObject.size.height,
  );
}
