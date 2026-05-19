import 'package:flutter/material.dart';

import 'ios_menu_models.dart';
import 'ios_menu_overlay.dart';

/// Circular three-dot button that opens a centred iOS-style menu.
class IosMoreButton extends StatefulWidget {
  const IosMoreButton({
    required this.sectionsBuilder,
    this.tooltip = 'More',
    this.size = 36,
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
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: SizedBox(
        key: _anchorKey,
        width: widget.size,
        height: widget.size,
        child: Material(
          color: scheme.surface,
          shape: CircleBorder(side: BorderSide(color: scheme.outline)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _open,
            child: Icon(
              Icons.more_horiz,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
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
