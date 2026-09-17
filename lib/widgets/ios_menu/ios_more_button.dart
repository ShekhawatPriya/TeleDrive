import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../native_glass_button.dart';
import 'ios_menu_models.dart';
import 'ios_menu_overlay.dart';
import 'native_menu_payload.dart';

/// UIKit owns iOS menu presentation and hit testing. Android and unavailable
/// bridges retain the anchored Flutter menu.
///
/// Set [alignToScreenEdge] when other actions (e.g. a profile avatar) sit to
/// the right of this button. The popup's right edge is then projected to the
/// screen edge so the menu lands at the same right inset regardless of which
/// action it visually trails.
class IosMoreButton extends StatefulWidget {
  const IosMoreButton({
    required this.sectionsBuilder,
    this.white = false,
    this.tooltip = 'More',
    this.size = 48,
    this.visualSize,
    this.alignToScreenEdge = false,
    super.key,
  });

  final IosMenuSectionsBuilder sectionsBuilder;
  final bool white;
  final String tooltip;
  final double size;
  final double? visualSize;
  final bool alignToScreenEdge;

  @override
  State<IosMoreButton> createState() => _IosMoreButtonState();
}

class _IosMoreButtonState extends State<IosMoreButton> {
  final GlobalKey _anchorKey = GlobalKey();
  Map<String, VoidCallback> _menuActions = {};

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _anchorKey,
      width: widget.size,
      height: widget.size,
      child: Theme.of(context).platform == TargetPlatform.iOS
          ? NativeGlassButton(
              label: widget.tooltip,
              white: widget.white,
              symbol: 'ellipsis',
              icon: CupertinoIcons.ellipsis,
              size: widget.size,
              visualSize: widget.visualSize,
              onPressed: _open,
              menuBuilder: () {
                final payload = NativeMenuPayload(
                  widget.sectionsBuilder(context),
                );
                _menuActions = payload.actions;
                return payload.sections;
              },
              onMenuAction: (id) => _menuActions[id]?.call(),
            )
          : IconButton(
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
