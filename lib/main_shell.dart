import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/app_update/app_update_controller.dart';
import 'features/app_update/app_update_models.dart';
import 'features/auth/auth_controller.dart';
import 'features/drive/components/drive_menu_builder.dart';
import 'features/drive/drive_controller.dart';
import 'features/drive/drive_tab_commands.dart';
import 'features/photos/components/photos_menu_builder.dart';
import 'features/photos/photos_grid/photo_grid_density.dart';
import 'features/profile/gallery_backup_asset_store.dart';
import 'features/profile/gallery_backup_controller.dart';
import 'features/search/search_controller.dart';
import 'features/share/share_controller.dart';
import 'features/upload/ui/components/bottom_action_system.dart';
import 'features/upload/ui/upload_panel_host.dart';
import 'widgets/ios_more_menu.dart';
import 'widgets/main_tab_menu_sections.dart';
import 'widgets/fab_anchor.dart';
import 'widgets/floating_pill_navigation_bar.dart';
import 'widgets/teledrive_app_bar.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(galleryBackupControllerProvider);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(galleryBackupControllerProvider).handleAppResumed());
      unawaited(
        ref
            .read(appUpdateControllerProvider)
            .checkForUpdate(reason: AppUpdateCheckReason.resume),
      );
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(const GalleryBackupAssetStore().flushAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    // Read above Scaffold: its resized body removes the keyboard inset.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 840;
        final content = UploadPanelHost(
          child: Builder(
            builder: (innerContext) => _buildTabs(
              innerContext,
              index,
              keyboardVisible: keyboardVisible,
            ),
          ),
        );
        return Scaffold(
          extendBody: !expanded,
          body: expanded
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: _handleDestinationSelected,
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Icon(
                          Icons.cloud_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      destinations: [
                        for (final item in driveDestinations)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selected),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: expanded
              ? null
              : FloatingPillNavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: _handleDestinationSelected,
                ),
        );
      },
    );
  }

  void _handleDestinationSelected(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (index == 0) ref.read(driveControllerProvider).setActiveFolderId(null);
    if (index == 3)
      unawaited(ref.read(shareControllerProvider).refresh(silent: true));
    widget.navigationShell.goBranch(index);
  }

  Widget _buildTabs(
    BuildContext context,
    int routeIndex, {
    required bool keyboardVisible,
  }) {
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
              widget.navigationShell,
              if (!keyboardVisible &&
                  !(isSelectMode &&
                      Theme.of(context).platform == TargetPlatform.iOS))
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
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
