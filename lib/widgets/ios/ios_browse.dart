import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show IosTint;
import '../../models/drive_models.dart';

/// Browsing surfaces on iOS: Drive, Starred, Shared, folders and the
/// Archive, Locked and Trash spaces.
///
/// Content sits on the plain system background, as in Files and Photos,
/// rather than the grouped Settings background. Tiles use the secondary
/// background, and system blue remains the only accent.
abstract final class IosBrowse {
  /// Content inset shared by every browsing page.
  static const double gutter = 20;

  static Color canvas(BuildContext context) =>
      CupertinoColors.systemBackground.resolveFrom(context);

  static Color fill(BuildContext context) =>
      CupertinoColors.secondarySystemBackground.resolveFrom(context);

  static Color separator(BuildContext context) =>
      CupertinoColors.separator.resolveFrom(context);

  /// Keeps pale thumbnails distinct from the canvas.
  static Color hairline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(
          alpha: MediaQuery.highContrastOf(context) ? .3 : .1,
        )
      : Colors.black.withValues(
          alpha: MediaQuery.highContrastOf(context) ? .3 : .07,
        );

  /// Tinted fill behind a symbol: system blue over the tile surface.
  static Color tint(BuildContext context) {
    final blue = Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return blue.withValues(alpha: dark ? .2 : .12);
  }

  /// iOS Dynamic Type roles with San Francisco tracking. Sizes still pass
  /// through the system text scaler.
  static TextStyle sectionTitle(BuildContext context) =>
      _base(context).copyWith(
        fontFamily: 'CupertinoSystemDisplay',
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.26,
      );

  static TextStyle headline(BuildContext context) => _base(
    context,
  ).copyWith(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.43);

  static TextStyle body(BuildContext context) =>
      _base(context).copyWith(fontSize: 17, letterSpacing: -.43);

  static TextStyle subheadline(BuildContext context, {FontWeight? weight}) =>
      _base(context).copyWith(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: weight ?? FontWeight.w400,
        letterSpacing: -.23,
      );

  static TextStyle footnote(BuildContext context, {Color? color}) =>
      _base(context).copyWith(
        fontSize: 13,
        height: 18 / 13,
        letterSpacing: -.08,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      );

  static TextStyle _base(BuildContext context) =>
      (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );
}

/// A system-blue symbol on a tinted circle, used wherever a space or
/// collection is identified so the same destination keeps the same mark.
class IosSymbolBadge extends StatelessWidget {
  const IosSymbolBadge(this.icon, {this.size = 36, super.key});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: IosBrowse.tint(context),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Icon(
      icon,
      size: size * .5,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

/// Immediate touch-down feedback for custom tiles. The scale is dropped
/// when Reduce Motion is enabled; the dimming still confirms the press.
class IosPressable extends StatefulWidget {
  const IosPressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<IosPressable> createState() => _IosPressableState();
}

class _IosPressableState extends State<IosPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? .97 : 1,
          duration: _pressed
              ? const Duration(milliseconds: 90)
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _pressed ? .72 : 1,
            duration: _pressed
                ? const Duration(milliseconds: 60)
                : const Duration(milliseconds: 220),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Section title for browsing pages, aligned to the content gutter.
class IosSectionTitle extends StatelessWidget {
  const IosSectionTitle(
    this.title, {
    this.top = 28,
    this.bottom = 12,
    this.trailing,
    super.key,
  });
  final String title;
  final double top, bottom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      IosBrowse.gutter,
      top,
      IosBrowse.gutter,
      bottom,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: IosBrowse.sectionTitle(context)),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// The iOS content-unavailable pattern: a secondary symbol, a short title,
/// one line of guidance and an optional action.
class IosContentUnavailable extends StatelessWidget {
  const IosContentUnavailable({
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    // Place inside a SliverFillRemaining(hasScrollBody: false) so it can grow
    // beyond the remaining space at large text sizes.
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: secondary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: IosBrowse.sectionTitle(context),
              ),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: IosBrowse.subheadline(
                    context,
                  ).copyWith(color: secondary),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                CupertinoButton(
                  minimumSize: const Size(44, 44),
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: IosBrowse.headline(
                      context,
                    ).copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A file without a preview: its kind's system tint on a soft fill with a
/// filled symbol, and the extension once there is room for it. Media kinds
/// use the same tints as the rest of the app ([IosTint]).
class IosFileGlyph extends StatelessWidget {
  const IosFileGlyph({required this.kind, this.extension, super.key});
  final FileKind kind;
  final String? extension;

  static (CupertinoDynamicColor, IconData) styleOf(
    FileKind kind,
  ) => switch (kind) {
    FileKind.image => (IosTint.photos, CupertinoIcons.photo_fill),
    FileKind.video => (IosTint.videos, CupertinoIcons.videocam_fill),
    FileKind.audio => (IosTint.audio, CupertinoIcons.music_note_2),
    FileKind.pdf => (CupertinoColors.systemRed, CupertinoIcons.doc_text_fill),
    FileKind.doc => (IosTint.documents, CupertinoIcons.doc_text_fill),
    FileKind.sheet => (CupertinoColors.systemGreen, CupertinoIcons.table_fill),
    FileKind.slides => (
      CupertinoColors.systemTeal,
      CupertinoIcons.rectangle_fill_on_rectangle_fill,
    ),
    FileKind.code => (
      CupertinoColors.systemIndigo,
      CupertinoIcons.chevron_left_slash_chevron_right,
    ),
    FileKind.zip => (IosTint.other, CupertinoIcons.cube_box_fill),
    FileKind.text => (IosTint.other, CupertinoIcons.doc_plaintext),
    FileKind.folder => (IosTint.documents, CupertinoIcons.folder_fill),
    FileKind.other => (IosTint.other, CupertinoIcons.doc_fill),
  };

  @override
  Widget build(BuildContext context) {
    final (tint, icon) = styleOf(kind);
    final color = tint.resolveFrom(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final size = side.isFinite ? side : 40.0;
        final label = size >= 88 && (extension?.isNotEmpty ?? false);
        return ColoredBox(
          color: Color.alphaBlend(
            color.withValues(alpha: dark ? .2 : .13),
            IosBrowse.canvas(context),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: size * (label ? .3 : .5), color: color),
                if (label) ...[
                  SizedBox(height: size * .06),
                  Text(
                    extension!.toUpperCase(),
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: IosBrowse.footnote(context, color: color).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
