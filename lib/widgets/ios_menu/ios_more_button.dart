import 'package:flutter/material.dart';

import 'ios_menu_models.dart';
import 'ios_menu_overlay.dart';

/// Three-dot overflow button rendered in the M3 style: a 40 dp `IconButton`
/// using the surrounding [IconButtonTheme]. Opens a Material 3 menu anchored
/// to the button.
///
/// Set [alignToScreenEdge] when other actions (e.g. a profile avatar) sit to
/// the right of this button. The popup's right edge is then projected to the
/// screen edge so the menu lands at the same right inset regardless of which
/// action it visually trails.
class IosMoreButton extends StatefulWidget {
  const IosMoreButton({
    required this.sectionsBuilder,
    this.tooltip = 'More',
    this.size = 48,
    this.alignToScreenEdge = false,
    super.key,
  });

  final IosMenuSectionsBuilder sectionsBuilder;
  final String tooltip;
  final double size;
  final bool alignToScreenEdge;

  @override
  State<IosMoreButton> createState() => _IosMoreButtonState();
}

class _IosMoreButtonState extends State<IosMoreButton> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _anchorKey,
      width: widget.size,
      height: widget.size,
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: _open,
        icon: Icon(
          Theme.of(context).platform == TargetPlatform.iOS
              ? Icons.more_horiz_rounded
              : Icons.more_vert,
        ),
      ),
    );
  }

  void _open() {
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    final box = renderObject.size;
    final right = widget.alignToScreenEdge
        ? MediaQuery.sizeOf(context).width
        : topLeft.dx + box.width;
    final anchor = Rect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      right,
      topLeft.dy + box.height,
    );
    showIosMoreMenu(
      context: context,
      anchor: anchor,
      sections: widget.sectionsBuilder(context),
    );
  }
}

Future<void> showIosMoreMenu({
  required BuildContext context,
  required Rect anchor,
  required List<IosMenuSection> sections,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(IosMenuOverlayRoute(anchor: anchor, sections: sections));
}
