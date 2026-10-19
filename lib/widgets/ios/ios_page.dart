import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../native_glass_button.dart';

/// Geometry shared by Settings-style iOS pages, measured from iOS 26 Settings.
abstract final class IosPageMetrics {
  /// Inline navigation bar height below the status bar.
  static const double barHeight = 44;

  /// Leading/trailing inset of navigation controls and inset groups.
  static const double margin = 16;

  /// Space between the navigation bar and the first group or hero card.
  static const double contentTop = 20;

  /// Continuous corner radius of inset groups and hero cards.
  static const double groupRadius = 26;

  /// Space after a group card; a footnote shortens it slightly.
  static const double groupSpacing = 36;
  static const double groupSpacingAfterFooter = 28;

  /// Minimum row height; rows grow with their text.
  static const double rowMinHeight = 52;
}

/// iOS Settings-style destinations: grouped inset content under a navigation
/// bar. Pushed pages ([compact]) use an inline centered title with the glass
/// Back button. When the page opens with an [IosSettingsIntro] hero, the inline
/// title stays hidden until the hero title scrolls beneath the bar, as in
/// Settings › General. Content scrolls under the bar, which only gains its
/// opaque background and soft edge once something is beneath it. Without
/// [compact], the page uses a collapsing large title, for root destinations.
class IosPage extends StatelessWidget {
  const IosPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.footer,
    this.onRefresh,
    this.controller,
    this.modal = false,
    this.compact = false,
    this.onBack,
    this.hero,
    this.horizontalPadding = IosPageMetrics.margin,
  });
  final double horizontalPadding;

  /// Whether the page opens with a hero whose title matches [title]. When
  /// null, an [IosSettingsIntro] among the first two children counts.
  final bool? hero;
  final String title;
  final List<Widget> children;
  final Widget? trailing, footer;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final bool modal, compact;
  final VoidCallback? onBack;

  bool get _hasIntro =>
      hero ?? children.take(2).any((child) => child is IosSettingsIntro);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inline = compact && !modal;
    final back = modal
        ? null
        : IosNavigationBar.backButton(
            context,
            onPressed: onBack,
            inScrollView: true,
          );
    return Scaffold(
      appBar: modal
          ? PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: _IosSheetHeader(title: title),
            )
          : null,
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          IosHeroScope(
            child: CustomScrollView(
              controller: controller,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                if (inline)
                  IosInlineTitleBar(
                    title: title,
                    hasHero: _hasIntro,
                    leading: back,
                    trailing: trailing,
                  )
                else if (!modal)
                  IosLargeTitleBar(
                    title: title,
                    backgroundColor: scheme.surface,
                    leading: Navigator.of(context).canPop() ? back : null,
                    trailing: trailing,
                  ),
                if (onRefresh != null)
                  CupertinoSliverRefreshControl(onRefresh: onRefresh),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    inline ? IosPageMetrics.contentTop : 12,
                    horizontalPadding,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(children: children),
                ),
              ],
            ),
          ),
          if (modal)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.surface,
                        scheme.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: footer,
    );
  }
}

/// Lets an [IosSettingsIntro] report where its title is to the page's
/// [IosInlineTitleBar], which reveals the inline title once the hero title
/// has scrolled beneath the bar. Wrap the scroll view of a page with a hero.
class IosHeroScope extends StatefulWidget {
  const IosHeroScope({super.key, required this.child});
  final Widget child;

  static GlobalKey? titleKeyOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_IosHeroScopeData>()?.titleKey;

  @override
  State<IosHeroScope> createState() => _IosHeroScopeState();
}

class _IosHeroScopeState extends State<IosHeroScope> {
  final _titleKey = GlobalKey(debugLabel: 'IosSettingsIntro title');
  @override
  Widget build(BuildContext context) =>
      _IosHeroScopeData(titleKey: _titleKey, child: widget.child);
}

class _IosHeroScopeData extends InheritedWidget {
  const _IosHeroScopeData({required this.titleKey, required super.child});
  final GlobalKey titleKey;
  @override
  bool updateShouldNotify(_IosHeroScopeData oldWidget) =>
      titleKey != oldWidget.titleKey;
}

/// The pinned inline navigation bar of a pushed page, as a sliver: the glass
/// Back control, a centered title and trailing actions (see
/// [IosNavigationBar]). Content scrolls beneath it; the bar takes
/// [backgroundColor] with a soft edge only while something is beneath it.
///
/// With [hasHero], the title stays hidden while the page's
/// [IosSettingsIntro] title is visible, as in Settings › General; the scroll
/// view must sit inside an [IosHeroScope].
class IosInlineTitleBar extends StatelessWidget {
  const IosInlineTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.hasHero = false,
    this.backgroundColor,
  });
  final String title;
  final Widget? leading, trailing;
  final bool hasHero;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _IosInlineBarDelegate(
      extent: MediaQuery.paddingOf(context).top + IosPageMetrics.barHeight,
      child: _IosInlineBarContent(bar: this),
    ),
  );
}

class _IosInlineBarDelegate extends SliverPersistentHeaderDelegate {
  const _IosInlineBarDelegate({required this.extent, required this.child});
  final double extent;
  final Widget child;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Listener(
        // The bar owns its area; taps do not reach content scrolled beneath.
        behavior: HitTestBehavior.opaque,
        child: child,
      );
  @override
  bool shouldRebuild(_IosInlineBarDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}

class _IosInlineBarContent extends StatefulWidget {
  const _IosInlineBarContent({required this.bar});
  final IosInlineTitleBar bar;
  @override
  State<_IosInlineBarContent> createState() => _IosInlineBarContentState();
}

class _IosInlineBarContentState extends State<_IosInlineBarContent> {
  ScrollPosition? _position;
  bool _scrolled = false;
  late bool _titleVisible = !widget.bar.hasHero;
  bool _updateScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position?..addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(_IosInlineBarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    super.dispose();
  }

  /// Positions are read after layout; scroll updates arrive before it.
  void _schedule() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _update();
    });
  }

  void _update() {
    final position = _position;
    final pixels = position != null && position.hasPixels
        ? position.pixels
        : 0.0;
    final scrolled = pixels > .5;
    var titleVisible = true;
    if (widget.bar.hasHero) {
      final bar = context.findRenderObject();
      final hero = IosHeroScope.titleKeyOf(context)?.currentContext;
      final title = hero?.findRenderObject();
      if (bar is RenderBox && title is RenderBox && title.attached) {
        final barBottom = bar.localToGlobal(Offset(0, bar.size.height)).dy;
        titleVisible =
            title.localToGlobal(Offset(0, title.size.height)).dy <= barBottom;
      } else {
        // Lazily built heroes are discarded once scrolled far away.
        titleVisible = scrolled;
      }
    }
    if (scrolled != _scrolled || titleVisible != _titleVisible) {
      setState(() {
        _scrolled = scrolled;
        _titleVisible = titleVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) => IosNavigationBar(
    title: widget.bar.title,
    titleVisible: _titleVisible,
    scrolledUnder: _scrolled,
    leading: widget.bar.leading,
    trailing: widget.bar.trailing,
    backgroundColor: widget.bar.backgroundColor,
  );
}

/// The iOS inline navigation bar: 44 points below the status bar, a 44-point
/// glass control at each 16-point margin and a centered 17-point semibold
/// title. It is transparent at rest; once content scrolls beneath it, it takes
/// the page background with a short soft edge, standing in for UIKit's scroll
/// edge effect. Use [IosNavigationBar.preferred] as a [Scaffold.appBar] for
/// pages that are not built on [IosPage].
class IosNavigationBar extends StatelessWidget {
  const IosNavigationBar({
    super.key,
    this.title,
    this.titleVisible = true,
    this.scrolledUnder = false,
    this.leading,
    this.trailing,
    this.backgroundColor,
  });
  final String? title;
  final bool titleVisible, scrolledUnder;
  final Widget? leading, trailing;

  /// The fill taken while content is beneath; the page background by default.
  final Color? backgroundColor;

  /// An opaque bar for a [Scaffold] whose body does not scroll beneath it.
  static PreferredSizeWidget preferred({
    String? title,
    Widget? leading,
    Widget? trailing,
  }) => PreferredSize(
    preferredSize: const Size.fromHeight(IosPageMetrics.barHeight),
    child: IosNavigationBar(
      title: title,
      leading: leading,
      trailing: trailing,
      scrolledUnder: true,
    ),
  );

  /// The standard glass Back control.
  /// Inside a scroll view, [inScrollView] hands touches to UIKit at once.
  static Widget backButton(
    BuildContext context, {
    VoidCallback? onPressed,
    bool inScrollView = false,
  }) => NativeGlassButton(
    label: 'Back',
    symbol: 'chevron.left',
    icon: CupertinoIcons.chevron_back,
    size: 44,
    symbolSize: 18,
    claimsTouches: inScrollView,
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = backgroundColor ?? scheme.surface;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: scrolledUnder ? 1 : 0,
            duration: duration,
            child: ColoredBox(color: background),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -12,
          height: 12,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: scrolledUnder ? 1 : 0,
              duration: duration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [background, background.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IosPageMetrics.margin,
            ),
            child: NavigationToolbar(
              leading: leading,
              middle: title == null
                  ? null
                  : AnimatedOpacity(
                      opacity: titleVisible ? 1 : 0,
                      duration: duration,
                      alwaysIncludeSemantics: true,
                      child: Semantics(
                        header: true,
                        // The bar cannot grow; the title caps its scaling like
                        // UIKit, which offers the large content viewer instead.
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.35,
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.4,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
              trailing: trailing,
              middleSpacing: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS large-title navigation for root and browsing pages, as a sliver.
///
/// A 44-point bar holds the glass controls at the 16-point margins; beneath
/// it, a 34-point bold title (and an optional [bottom], such as search) scroll
/// up under the bar. [bottom] tucks away first, then the title, after which
/// the inline title fades into the bar. The bar is transparent at rest and only
/// takes [backgroundColor] with a soft edge once content scrolls beneath it,
/// so floating glass controls are never cut by a hard bar edge. With
/// [pinBottom], [bottom] stays below the bar (for example while a query is
/// shown).
class IosLargeTitleBar extends StatelessWidget {
  const IosLargeTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.bottom,
    this.pinBottom = false,
    this.backgroundColor,
    this.titleInset = IosPageMetrics.margin,
  });
  final String title;
  final Widget? leading, trailing;
  final PreferredSizeWidget? bottom;
  final bool pinBottom;
  final Color? backgroundColor;

  /// Leading inset of the large title; browsing pages align it to their
  /// 20-point content gutter.
  final double titleInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // UIKit caps the large title's growth; very large text uses the inline
    // title and the large content viewer instead.
    final scaler = media.textScaler.clamp(maxScaleFactor: 1.5);
    final titleHeight = (scaler.scale(34) * 1.2 + 12).ceilToDouble();
    return SliverPersistentHeader(
      pinned: true,
      delegate: _IosLargeTitleDelegate(
        bar: this,
        top: media.padding.top,
        titleHeight: titleHeight,
        bottomHeight: bottom?.preferredSize.height ?? 0,
        scaler: scaler,
        background: backgroundColor ?? Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

class _IosLargeTitleDelegate extends SliverPersistentHeaderDelegate {
  _IosLargeTitleDelegate({
    required this.bar,
    required this.top,
    required this.titleHeight,
    required this.bottomHeight,
    required this.scaler,
    required this.background,
  });
  final IosLargeTitleBar bar;
  final double top, titleHeight, bottomHeight;
  final TextScaler scaler;
  final Color background;

  double get _barBottom => top + IosPageMetrics.barHeight;

  @override
  double get maxExtent => _barBottom + titleHeight + bottomHeight;

  @override
  double get minExtent => _barBottom + (bar.pinBottom ? bottomHeight : 0);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;
    final double collapsed, visibleBottom;
    if (bar.pinBottom) {
      collapsed = shrinkOffset.clamp(0.0, titleHeight);
      visibleBottom = bottomHeight;
    } else {
      visibleBottom = (bottomHeight - shrinkOffset).clamp(0.0, bottomHeight);
      collapsed = (shrinkOffset - bottomHeight).clamp(0.0, titleHeight);
    }
    final scrolledUnder = shrinkOffset > maxExtent - minExtent + .5;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Listener(
      // The bar owns its area; taps do not reach content scrolled beneath.
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: scrolledUnder ? 1 : 0,
              duration: duration,
              child: ColoredBox(color: background),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -12,
            height: 12,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: scrolledUnder ? 1 : 0,
                duration: duration,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [background, background.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The title and bottom slide up beneath the bar, clipped at its edge.
          Positioned(
            top: _barBottom,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -collapsed,
                    left: bar.titleInset,
                    right: IosPageMetrics.margin,
                    height: titleHeight,
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Semantics(
                          header: true,
                          child: Text(
                            bar.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: scaler,
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .37,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (bar.bottom != null)
                    Positioned(
                      top: titleHeight - collapsed,
                      left: 0,
                      right: 0,
                      height: visibleBottom,
                      child: bar.bottom!,
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _barBottom,
            child: ExcludeSemantics(
              // The large title already names the page until it collapses.
              excluding: collapsed < titleHeight - 4,
              child: IosNavigationBar(
                title: bar.title,
                titleVisible: collapsed >= titleHeight - 4,
                leading: bar.leading,
                trailing: bar.trailing,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_IosLargeTitleDelegate oldDelegate) => true;
}

/// A quiet, fixed sheet header; the route continues to own drag gestures.
class _IosSheetHeader extends StatelessWidget {
  const _IosSheetHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                NativeGlassButton(
                  label: 'Close',
                  symbol: 'xmark',
                  icon: CupertinoIcons.xmark,
                  size: 44,
                  symbolSize: 15,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An inset grouped section: an optional header outside the card, the rows,
/// and an optional explanatory footnote below it.
///
/// Headers are one to three words in title case. Footnotes are one or two
/// sentences explaining the consequence of the group's controls.
class IosGroup extends StatelessWidget {
  const IosGroup({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.bottomSpacing,
    this.dividerInset,
  });
  final double? bottomSpacing;
  final double? dividerInset;
  final String? title, footer;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            bottomSpacing ??
            (footer == null
                ? IosPageMetrics.groupSpacing
                : IosPageMetrics.groupSpacingAfterFooter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          // Own the clip: CupertinoListSection applies a fixed corner radius
          // even when its decoration specifies a different radius.
          ClipRSuperellipse(
            borderRadius: BorderRadius.circular(IosPageMetrics.groupRadius),
            child: ColoredBox(
              color: scheme.surfaceContainerLow,
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start:
                              dividerInset ?? _separatorStart(children[index]),
                          end: 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 1 / MediaQuery.devicePixelRatioOf(context),
                          child: ColoredBox(color: scheme.outlineVariant),
                        ),
                      ),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.38,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Separators start where the row's title starts.
  static double _separatorStart(Widget child) {
    if (child is IosRow) return child.titleStart;
    if (child is Semantics && child.child != null) {
      return _separatorStart(child.child!);
    }
    return 16;
  }
}

class IosRow extends StatelessWidget {
  const IosRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.value,
    this.trailing,
    this.onTap,
    this.leading,
    this.destructive = false,
    this.action = false,
    this.enabled = true,
  });
  final String title;
  final String? subtitle, value;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool destructive, action, enabled;

  static const double _iconSize = 28, _leadingSize = 40;

  /// Leading inset: icon tiles sit at 12 points, plain titles at 16.
  double get _start => leading != null || icon != null ? 12 : 16;
  double get _leadingToTitle => leading != null ? 12 : 14;

  /// Where the title begins, which is also where the separator above starts.
  double get titleStart => leading != null
      ? _start + _leadingSize + _leadingToTitle
      : icon != null
      ? _start + _iconSize + _leadingToTitle
      : _start;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(17) > 24;
    // System tints are dynamic; resolve them so dark mode gets UIKit's
    // dark variants rather than the light values stored on the constant.
    final tint = CupertinoDynamicColor.resolve(
      color ?? scheme.primary,
      context,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: IosPageMetrics.rowMinHeight),
      child: CupertinoListTile.notched(
        backgroundColor: scheme.surfaceContainerLow,
        padding: EdgeInsetsDirectional.fromSTEB(_start, 11, 16, 11),
        leadingSize: leading == null ? _iconSize : _leadingSize,
        leadingToTitle: _leadingToTitle,
        leading:
            leading ??
            (icon == null
                ? null
                : DecoratedBox(
                    decoration: ShapeDecoration(
                      color: tint,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: _iconSize,
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
                  )),
        title: Text(
          title,
          maxLines: 4,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -.4,
            color: !enabled
                ? scheme.onSurfaceVariant.withValues(alpha: .55)
                : destructive
                ? scheme.error
                : action
                ? scheme.primary
                : scheme.onSurface,
          ),
        ),
        subtitle: subtitle == null && (!large || value == null)
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  [
                    if (subtitle != null) subtitle!,
                    if (large && value != null) value!,
                  ].join('\n'),
                  maxLines: 8,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
        additionalInfo: value != null && !large
            ? Text(
                value!,
                style: TextStyle(
                  fontSize: 17,
                  letterSpacing: -.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing:
            trailing ??
            (onTap != null ? const CupertinoListTileChevron() : null),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class IosNote extends StatelessWidget {
  const IosNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.38),
    ),
  );
}

/// The hero card that opens a Settings category: a 60-point symbol tile, the
/// category name in bold and one or two sentences on what the page manages,
/// optionally ending with an inline "Learn more…" link to a real destination.
///
/// Its [title] should match the page title: on an [IosPage], the inline bar
/// title appears only once this title scrolls beneath the bar.
class IosSettingsIntro extends StatefulWidget {
  const IosSettingsIntro({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.onLearnMore,
    this.learnMoreLabel = 'Learn more…',
    this.fill,
  });
  final IconData icon;
  final Color color;

  /// The card surface; browsing pages on the white canvas pass their tile
  /// fill. Grouped pages use the inset group surface.
  final Color? fill;
  final String title, description, learnMoreLabel;
  final VoidCallback? onLearnMore;

  @override
  State<IosSettingsIntro> createState() => _IosSettingsIntroState();
}

class _IosSettingsIntroState extends State<IosSettingsIntro> {
  final _learnMore = TapGestureRecognizer();

  @override
  void dispose() {
    _learnMore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _learnMore.onTap = widget.onLearnMore;
    final descriptionStyle = TextStyle(
      fontSize: 16,
      height: 1.42,
      letterSpacing: -.3,
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: IosPageMetrics.groupSpacing),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(IosPageMetrics.groupRadius),
        child: ColoredBox(
          color: widget.fill ?? scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            // Leading-aligned, as the category cards in iOS Settings
            // (Mobile Service, General, Camera) present their symbol, title
            // and description.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: CupertinoDynamicColor.resolve(
                        widget.color,
                        context,
                      ),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 60,
                      child: Icon(widget.icon, size: 34, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    widget.title,
                    key: IosHeroScope.titleKeyOf(context),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: widget.description,
                    children: [
                      if (widget.onLearnMore != null) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: widget.learnMoreLabel,
                          style: TextStyle(color: scheme.primary),
                          recognizer: _learnMore,
                          semanticsLabel: widget.learnMoreLabel,
                        ),
                      ],
                    ],
                  ),
                  textAlign: TextAlign.start,
                  style: descriptionStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
