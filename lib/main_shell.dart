import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/drive/components/drive_menu_builder.dart';
import 'features/drive/drive_controller.dart';
import 'features/drive/drive_screen.dart';
import 'features/drive/drive_tab_commands.dart';
import 'features/drive/starred_screen.dart';
import 'features/photos/components/photos_menu_builder.dart';
import 'features/photos/photos_grid/photo_grid_density.dart';
import 'features/photos/photos_screen.dart';
import 'features/profile/gallery_backup_controller.dart';
import 'features/search/search_controller.dart';
import 'features/share/my_shares_screen.dart';
import 'features/share/share_controller.dart';
import 'features/upload/ui/components/bottom_action_system.dart';
import 'widgets/ios_more_menu.dart';
import 'widgets/main_tab_menu_sections.dart';
import 'widgets/fab_anchor.dart';
import 'widgets/floating_pill_navigation_bar.dart';
import 'widgets/teledrive_app_bar.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _tabPaths = ['/drive', '/photos', '/starred', '/shared'];
  static const _tabPages = [
    _KeepAliveTab(child: DriveScreen()),
    _KeepAliveTab(child: PhotosScreen()),
    _KeepAliveTab(child: StarredScreen()),
    _KeepAliveTab(child: MySharesScreen()),
  ];

  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth.isAuthenticated && auth.telegramConnected == true) {
        final drive = ref.read(driveControllerProvider);
        final bootstrap = auth.takePendingDriveBootstrap();
        bootstrap == null
            ? drive.refresh(force: true)
            : drive.applyDriveState(bootstrap);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(galleryBackupControllerProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final routeIndex = _tabIndexFor(location);
    final showingTab = routeIndex >= 0;
    if (showingTab && routeIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectedIndex = routeIndex;
        if (_pageController.hasClients) _pageController.jumpToPage(routeIndex);
        setState(() {});
      });
    }

    return Scaffold(
      body: showingTab ? _buildTabs(routeIndex) : widget.child,
      bottomNavigationBar: showingTab
          ? FloatingPillNavigationBar(
              selectedIndex: routeIndex.clamp(0, _tabPaths.length - 1),
              onDestinationSelected: _handleDestinationSelected,
            )
          : null,
    );
  }

  int _tabIndexFor(String location) =>
      _tabPaths.indexWhere(location.startsWith);

  void _handleDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: AppDurations.medium3,
      curve: AppEasing.emphasizedDecelerate,
    );
    context.go(_tabPaths[index]);
  }

  Widget _buildTabs(int routeIndex) {
    final selectState = ref.watch(selectionModeStateProvider);
    final isSelectMode = selectState.isSelectModeForTab(routeIndex);
    return Column(
      children: [
        if (!isSelectMode)
          TeleDriveTopBar(
            scope: _scopeFor(routeIndex),
            menuSections: (ctx) => _menuSectionsFor(ctx, routeIndex),
          ),
        Expanded(
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: _handlePageChanged,
                children: _tabPages,
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: FabAnchorPublisher(
                  child: BottomActionSystem(
                    showFab: routeIndex == 0,
                    parentId: null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handlePageChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    context.go(_tabPaths[index]);
  }

  SearchScope _scopeFor(int index) => switch (index) {
    0 => SearchScope.drive,
    1 => SearchScope.photos,
    2 => SearchScope.starred,
    _ => SearchScope.shared,
  };

  List<IosMenuSection> _menuSectionsFor(BuildContext context, int index) {
    return switch (index) {
      0 => buildDriveMenuSections(
        context,
        ref,
        folderId: null,
        includeLayoutSection: true,
        onSelect: () => ref.read(driveTabCommandsProvider).requestSelectMode(),
      ),
      1 => buildPhotosMenuSections(
        context,
        density: ref.read(photoGridDensityProvider),
      ),
      2 => [...buildLayoutMenuSection(ref), ...buildSortMenuSection(ref)],
      _ => [
        IosMenuSection([
          IosMenuItem(
            label: 'Refresh',
            leadingIcon: Icons.refresh_rounded,
            onTap: () =>
                ref.read(shareControllerProvider).refresh(silent: true),
          ),
        ]),
        ...buildLayoutMenuSection(ref),
      ],
    };
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});
  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
