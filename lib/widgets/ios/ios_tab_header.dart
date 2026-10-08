import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/search/search_controller.dart';
import '../account_button.dart';
import '../drive_search_field.dart';
import '../ios_more_menu.dart';
import '../native_glass_button.dart';
import 'ios_browse.dart';

/// Gives browsing pages their canvas and lets [IosLargeTitleHeader] reveal
/// its hairline only once content scrolls beneath it, as UIKit does.
class IosBrowseCanvas extends StatelessWidget {
  const IosBrowseCanvas({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canvas = IosBrowse.canvas(context);
    return ColoredBox(
      color: canvas,
      child: CupertinoPageScaffoldBackgroundColor(color: canvas, child: child),
    );
  }
}

/// iOS large-title navigation for browsing pages. The title collapses into
/// the bar on scroll; trailing controls stay pinned. The bar is opaque
/// because item rows host UIKit hold views that a Flutter blur cannot sample.
class IosLargeTitleHeader extends StatelessWidget {
  const IosLargeTitleHeader({
    required this.title,
    this.leading,
    this.trailing,
    this.bottom,
    this.pinBottom = false,
    super.key,
  });
  final String title;
  final Widget? leading, trailing;
  final PreferredSizeWidget? bottom;

  /// Keeps [bottom] visible while scrolling, e.g. while a query is shown.
  final bool pinBottom;

  /// A back control that matches the native glass bar buttons.
  static Widget backButton(BuildContext context) => NativeGlassButton(
    claimsTouches: true,
    label: 'Back',
    symbol: 'chevron.left',
    icon: CupertinoIcons.chevron_back,
    size: 44,
    symbolSize: 17,
    onPressed: () => Navigator.of(context).maybePop(),
  );

  @override
  Widget build(BuildContext context) {
    final canvas = IosBrowse.canvas(context);
    return CupertinoSliverNavigationBar(
      // UIKit's large title starts 16 points in; browsing content uses a
      // 20-point gutter, so the title shares its leading edge.
      largeTitle: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(title),
      ),
      middle: Text(title),
      alwaysShowMiddle: false,
      automaticallyImplyLeading: false,
      automaticallyImplyTitle: false,
      leading: leading,
      trailing: trailing,
      transitionBetweenRoutes: false,
      backgroundColor: canvas,
      border: Border(
        bottom: BorderSide(color: IosBrowse.separator(context), width: 0),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      bottom: bottom,
      bottomMode: bottom == null
          ? null
          : pinBottom
          ? NavigationBarBottomMode.always
          : NavigationBarBottomMode.automatic,
    );
  }
}

/// The trailing controls shared by every tab header: the overflow menu in a
/// 44-point glass capsule, as in the Files app, beside the account entry.
class IosHeaderActions extends StatelessWidget {
  const IosHeaderActions({
    required this.menuSections,
    required this.tooltip,
    super.key,
  });
  final IosMenuSectionsBuilder menuSections;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IosMoreButton(
        claimsTouches: true,
        sectionsBuilder: menuSections,
        tooltip: tooltip,
        size: 44,
      ),
      const SizedBox(width: 8),
      const SizedBox(
        width: 44,
        height: 44,
        child: AccountButton(avatarSize: 40),
      ),
    ],
  );
}

/// The header for the Drive, Starred and Shared tabs: large title, scoped
/// search that tucks under the title while browsing, the overflow menu and
/// the account entry point.
class IosTabHeader extends ConsumerWidget {
  const IosTabHeader({
    required this.scope,
    required this.menuSections,
    super.key,
  });
  final SearchScope scope;
  final IosMenuSectionsBuilder menuSections;

  static String titleFor(SearchScope scope) => switch (scope) {
    SearchScope.drive => 'Drive',
    SearchScope.photos => 'Photos',
    SearchScope.starred => 'Starred',
    SearchScope.shared => 'Shared',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searching = ref.watch(
      searchQueryProvider(scope).select((query) => query.raw.isNotEmpty),
    );
    final title = titleFor(scope);
    return IosLargeTitleHeader(
      title: title,
      pinBottom: searching,
      trailing: IosHeaderActions(
        menuSections: menuSections,
        tooltip: '$title options',
      ),
      bottom: _SearchBottom(
        scope: scope,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }
}

class _SearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const _SearchBottom({required this.scope, required this.textScaler});
  final SearchScope scope;
  final TextScaler textScaler;

  static const _top = 2.0, _bottom = 10.0;

  double get _field => (textScaler.scale(17) + 30).clamp(48.0, 76.0);

  @override
  Size get preferredSize => Size.fromHeight(_top + _field + _bottom);

  @override
  Widget build(BuildContext context) {
    final full = preferredSize.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        // While the field tucks under the title it is clipped by the bar and
        // fades, keeping the UIKit search view at its natural size.
        final visible = constraints.maxHeight.isFinite
            ? (constraints.maxHeight / full).clamp(0.0, 1.0)
            : 1.0;
        final opacity = ((visible - .35) / .65).clamp(0.0, 1.0);
        return OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: full,
          maxHeight: full,
          child: IgnorePointer(
            ignoring: visible < .6,
            child: Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  IosBrowse.gutter,
                  _top,
                  IosBrowse.gutter,
                  _bottom,
                ),
                child: DriveSearchField(
                  key: ValueKey(scope),
                  scope: scope,
                  inScrollingHeader: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
