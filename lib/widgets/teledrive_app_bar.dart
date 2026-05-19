import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';
import '../features/search/search_controller.dart';
import 'ios_more_menu.dart';
import 'profile_avatar.dart';

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
      leadingWidth: 48,
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
                const SizedBox(width: 48, child: _LogoLeading()),
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(Icons.cloud_rounded, color: scheme.primary, size: 26),
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
    if (menuSections != null) IosMoreButton(sectionsBuilder: menuSections),
    Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxs,
        0,
        AppSpacing.sm,
        0,
      ),
      child: GestureDetector(
        onTap: () => context.push('/profile'),
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

class _RotatingHint extends StatefulWidget {
  const _RotatingHint({required this.scope});

  final SearchScope scope;

  @override
  State<_RotatingHint> createState() => _RotatingHintState();
}

class _RotatingHintState extends State<_RotatingHint> {
  static const _interval = Duration(milliseconds: 3500);
  Timer? _timer;
  int _index = 0;

  static const _phrases = <SearchScope, List<String>>{
    SearchScope.drive: [
      'Search files and folders',
      'Find a PDF',
      'Find a folder by name',
      'Search images & videos',
    ],
    SearchScope.photos: [
      'Search photos and videos',
      'Find by file name',
      'Find by date',
    ],
    SearchScope.starred: [
      'Search starred items',
      'Starred files',
      'Starred folders',
    ],
    SearchScope.shared: [
      'Search shared items',
      'Find a shared link',
      'Search by recipient name',
    ],
  };

  List<String> get _list => _phrases[widget.scope]!;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _list.length);
    });
  }

  @override
  void didUpdateWidget(covariant _RotatingHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motion = theme.extension<AppMotion>();
    return AnimatedSwitcher(
      duration: motion?.durationMedium ?? const Duration(milliseconds: 250),
      switchInCurve: motion?.emphasized ?? Curves.easeOutCubic,
      switchOutCurve: motion?.emphasized ?? Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          ),
        );
      },
      child: Text(
        _list[_index],
        key: ValueKey<int>(_index),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
