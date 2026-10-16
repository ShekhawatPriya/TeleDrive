import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One vocabulary for an item's state on iOS, used wherever a file or folder
/// appears:
///
/// * **Starred** – `star.fill` in system yellow.
/// * **Shared** – `link` in the secondary label colour: the item has a share
///   link. Folders keep the plain folder symbol; the link marks sharing.
///
/// Wherever an item has a metadata line (rows, tiles with captions, sheet
/// headers, viewers), [ItemStatusInline] leads that line, as Files places tags
/// beside an item's details. Media-only tiles without a caption (the Photos
/// grid) use [ItemStatusOverlay]. Menus describe the same state in words with
/// [itemStatusText].
abstract final class ItemStatus {
  static const starSymbol = CupertinoIcons.star_fill;
  static const sharedSymbol = CupertinoIcons.link;

  static Color starColor(BuildContext context) =>
      CupertinoColors.systemYellow.resolveFrom(context);

  static Color sharedColor(BuildContext context) =>
      CupertinoColors.secondaryLabel.resolveFrom(context);
}

/// "Starred · Shared", "Starred", "Shared" or an empty string.
String itemStatusText({required bool starred, required bool shared}) =>
    [if (starred) 'Starred', if (shared) 'Shared'].join(' · ');

/// Small status symbols sized to sit before a metadata line.
class ItemStatusInline extends StatelessWidget {
  const ItemStatusInline({
    super.key,
    required this.starred,
    required this.shared,
    this.size = 13,
    this.spacing = 4,
  });

  final bool starred, shared;
  final double size, spacing;

  bool get visible => starred || shared;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final scaled = MediaQuery.textScalerOf(context).scale(size);
    return Semantics(
      label: itemStatusText(starred: starred, shared: shared),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (starred)
              Icon(
                ItemStatus.starSymbol,
                size: scaled,
                color: ItemStatus.starColor(context),
              ),
            if (starred && shared) SizedBox(width: spacing),
            if (shared)
              Icon(
                ItemStatus.sharedSymbol,
                size: scaled,
                color: ItemStatus.sharedColor(context),
              ),
            SizedBox(width: spacing + 1),
          ],
        ),
      ),
    );
  }
}

/// Status over media with no caption: white symbols on a small dark pill so
/// they stay legible on any image.
class ItemStatusOverlay extends StatelessWidget {
  const ItemStatusOverlay({
    super.key,
    required this.starred,
    required this.shared,
  });

  final bool starred, shared;

  @override
  Widget build(BuildContext context) {
    if (!starred && !shared) return const SizedBox.shrink();
    return Semantics(
      label: itemStatusText(starred: starred, shared: shared),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            color: Color(0x73000000),
            shape: StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (starred)
                  const Icon(
                    ItemStatus.starSymbol,
                    size: 12,
                    color: Colors.white,
                  ),
                if (starred && shared) const SizedBox(width: 3),
                if (shared)
                  const Icon(
                    ItemStatus.sharedSymbol,
                    size: 12,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A metadata line led by the item's status symbols.
class ItemStatusLine extends StatelessWidget {
  const ItemStatusLine({
    super.key,
    required this.text,
    required this.starred,
    required this.shared,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.center = false,
  });

  final String text;
  final bool starred, shared;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final size = (style?.fontSize ?? 13) - 1;
    return Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        ItemStatusInline(starred: starred, shared: shared, size: size),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: maxLines == null
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          ),
        ),
      ],
    );
  }
}
