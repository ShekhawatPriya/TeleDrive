import 'package:flutter/material.dart';

import 'ios_menu_models.dart';
import 'ios_menu_overlay.dart';

/// Three-dot overflow button rendered in the M3 style: a 40dp `IconButton`
/// using the surrounding [IconButtonTheme]. Opens a Material 3 menu anchored
/// to the button.
///
/// The class name is kept for backwards compatibility with existing call
/// sites (`drive_screen.dart`, `folder_screen.dart`, etc.). The menu it
/// produces is fully Material 3 — see [showIosMoreMenu] / [IosMenuOverlayRoute].
class IosMoreButton extends StatefulWidget {
  const IosMoreButton({
    required this.sectionsBuilder,
    this.tooltip = 'More',
    this.size = 40,
    super.key,
  });

  final IosMenuSectionsBuilder sectionsBuilder;
  final String tooltip;
  final double size;

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
        icon: const Icon(Icons.more_vert),
      ),
    );
  }

  void _open() {
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    final anchor = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      renderObject.size.width,
      renderObject.size.height,
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
