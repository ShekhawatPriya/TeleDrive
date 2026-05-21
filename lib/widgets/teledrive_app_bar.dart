import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/search/search_controller.dart';
import 'ios_more_menu.dart';
import 'profile_avatar.dart';
import '../features/profile/widgets/account_bottom_sheet.dart';

/// Shared top app bar for the four main-tab surfaces: Drive, Photos,
/// Starred, Shared. Renders identically on every screen — only the search
/// scope, the rotating placeholder phrases, and the overflow-menu sections
/// change per screen.
///
/// Layout: `[ ☁ logo ] [ search pill ] [ ⋮ ] [ avatar ]`.
///
/// Returns a `SliverAppBar`, so callers must place it inside a
/// `CustomScrollView`. Background is fully opaque (theme `surface`) and the
/// theme's `scrolledUnderElevation` provides the subtle tint when content
/// scrolls beneath.
class TeleDriveAppBar extends ConsumerWidget {
  const TeleDriveAppBar({required this.scope, this.menuSections, super.key});

  final SearchScope scope;
  final IosMenuSectionsBuilder? menuSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      titleSpacing: AppSpacing.sm,
      leadingWidth: 54,
      leading: const _LogoLeading(),
      title: _SearchPill(scope: scope),
      actions: _buildAppBarActions(context, ref, menuSections),
    );
  }
}

class TeleDriveTopBar extends ConsumerWidget {
  const TeleDriveTopBar({required this.scope, this.menuSections, super.key});

  final SearchScope scope;
  final IosMenuSectionsBuilder? menuSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
            child: Row(
              children: [
                const SizedBox(width: 54, child: _LogoLeading()),
                Expanded(child: _SearchPill(scope: scope)),
                ..._buildAppBarActions(context, ref, menuSections),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoLeading extends StatelessWidget {
  const _LogoLeading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: 28,
        height: 28,
      ),
    );
  }
}

List<Widget> _buildAppBarActions(
  BuildContext context,
  WidgetRef ref,
  IosMenuSectionsBuilder? menuSections,
) {
  final auth = ref.watch(authControllerProvider);
  return [
    if (menuSections != null)
      IosMoreButton(
        sectionsBuilder: menuSections,
        alignToScreenEdge: true,
      ),
    Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxs,
        0,
        AppSpacing.sm,
        0,
      ),
      child: GestureDetector(
        onTap: () {
          final screenHeight = MediaQuery.of(context).size.height;
          final topPadding = MediaQuery.of(context).padding.top;
          final notchHeight = topPadding > 0.0
              ? topPadding
              : MediaQueryData.fromView(View.of(context)).padding.top;
          final maxSheetHeight = (screenHeight - (notchHeight + 64.0 + 12.0)).clamp(0.0, double.infinity);

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            useRootNavigator: true,
            showDragHandle: false,
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            builder: (context) => const AccountBottomSheet(),
          );
        },
        child: ProfileAvatar(user: auth.user, size: 36),
      ),
    ),
  ];
}

class _SearchPill extends ConsumerStatefulWidget {
  const _SearchPill({required this.scope});

  final SearchScope scope;

  @override
  ConsumerState<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends ConsumerState<_SearchPill> {
  final _focus = FocusNode();
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    // Pre-seed the field if the user navigated back to a tab that already
    // has an active query.
    final initial = ref.read(searchQueryProvider(widget.scope)).raw;
    if (initial.isNotEmpty) _text.text = initial;
  }

  @override
  void didUpdateWidget(covariant _SearchPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope == widget.scope) return;
    final next = ref.read(searchQueryProvider(widget.scope)).raw;
    if (_text.text != next) _text.text = next;
    _focus.unfocus();
    setState(() {});
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final searchCtrl = ref.watch(searchQueryProvider(widget.scope));
    final hasText = _text.text.isNotEmpty;
    final focused = _focus.hasFocus;

    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 1,
      shadowColor: scheme.shadow,
      surfaceTintColor: scheme.surfaceTint,
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.search, color: scheme.onSurfaceVariant, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (!focused && !hasText)
                      IgnorePointer(child: _RotatingHint(scope: widget.scope)),
                    TextField(
                      controller: _text,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyLarge,
                      cursorColor: scheme.primary,
                      decoration: const InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (value) {
                        searchCtrl.update(value);
                        setState(() {}); // refresh clear-button visibility
                      },
                    ),
                  ],
                ),
              ),
              if (hasText)
                IconButton(
                  tooltip: 'Clear',
                  iconSize: 20,
                  onPressed: () {
                    _text.clear();
                    searchCtrl.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              else
                const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _RotatingHint extends ConsumerWidget {
  const _RotatingHint({required this.scope});

  final SearchScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phrase = ref.watch(rotatingPlaceholderProvider).currentPhrase;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey<String>(phrase);

        // Sequence the transition:
        // By applying an Interval(0.5, 1.0), the exit and entry transitions
        // run sequentially without any overlap:
        // - Outgoing completes its exit (1.0 -> 0.0) from t = 0.0 to 0.5.
        // - Incoming completes its entry (0.0 -> 1.0) from t = 0.5 to 1.0.
        final sequencedAnimation = animation.drive(
          CurveTween(curve: const Interval(0.5, 1.0, curve: Curves.easeInOutCubic)),
        );

        final slide = Tween<Offset>(
          begin: isIncoming ? const Offset(0, 1.0) : const Offset(0, -1.0),
          end: Offset.zero,
        ).animate(sequencedAnimation);

        return ClipRect(
          child: FadeTransition(
            opacity: sequencedAnimation,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        phrase,
        key: ValueKey<String>(phrase),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
