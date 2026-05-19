import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/drive/drive_controller.dart';
import 'features/drive/drive_screen.dart';
import 'features/drive/folder_screen.dart';
import 'features/file_viewer/file_viewer_screen.dart';
import 'features/photos/photos_filter.dart';
import 'features/photos/photos_screen.dart';
import 'features/photos/photos_viewer/photo_viewer_screen.dart';
import 'features/profile/legal_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/theme_controller.dart';
import 'features/share/share_detail_screen.dart';
import 'features/upload/ui/folder_creation/folder_toast_overlay.dart';
import 'features/upload/ui/upload_overlay.dart';
import 'shared/splash_screen.dart';

class TeleDriveApp extends ConsumerWidget {
  const TeleDriveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final theme = ref.watch(themeControllerProvider);
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        if (auth.loading) return state.matchedLocation == '/' ? null : '/';
        final loggingIn = state.matchedLocation == '/login';
        if (!auth.isAuthenticated) return loggingIn ? null : '/login';
        if (loggingIn || state.matchedLocation == '/') return '/drive';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/drive', builder: (_, __) => const DriveScreen()),
            GoRoute(path: '/photos', builder: (_, __) => const PhotosScreen()),
            GoRoute(
              path: '/starred',
              builder: (_, __) => const StarredScreen(),
            ),
            GoRoute(path: '/shared', builder: (_, __) => const SharedScreen()),
          ],
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(
          path: '/folder/:id',
          builder: (_, state) =>
              FolderScreen(folderId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/shared/:id',
          builder: (_, state) =>
              ShareDetailScreen(shareId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/file/:id',
          builder: (_, state) =>
              FileViewerScreen(fileId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/photos/view/:id',
          builder: (_, state) => PhotoViewerScreen(
            startId: state.pathParameters['id']!,
            filter: PhotosFilterX.fromQuery(
              state.uri.queryParameters['filter'],
            ),
          ),
        ),
        GoRoute(
          path: '/privacy',
          builder: (_, __) => const LegalScreen(kind: LegalKind.privacy),
        ),
        GoRoute(
          path: '/terms',
          builder: (_, __) => const LegalScreen(kind: LegalKind.terms),
        ),
      ],
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightFallback = ColorScheme.fromSeed(
          seedColor: AppBrand.seed,
          brightness: Brightness.light,
        );
        final darkFallback = ColorScheme.fromSeed(
          seedColor: AppBrand.seed,
          brightness: Brightness.dark,
        );
        final lightScheme = (lightDynamic ?? lightFallback).harmonized();
        final darkScheme = (darkDynamic ?? darkFallback).harmonized();
        return MaterialApp.router(
          title: 'TeleDrive',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(lightScheme),
          darkTheme: buildTheme(darkScheme),
          themeMode: theme.mode,
          routerConfig: router,
        );
      },
    );
  }
}

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
    _KeepAliveTab(child: SharedScreen()),
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth.isAuthenticated && auth.telegramConnected == true) {
        final drive = ref.read(driveControllerProvider);
        final bootstrap = auth.takePendingDriveBootstrap();
        if (bootstrap != null) {
          drive.applyDriveState(bootstrap);
        } else {
          drive.refresh(force: true);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = _tabIndexFor(GoRouterState.of(context).matchedLocation);
    if (index >= 0) _selectedIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final routeIndex = _tabIndexFor(location);
    final showingTab = routeIndex >= 0;

    return Scaffold(
      body: Stack(
        children: [
          if (showingTab)
            PageTransitionSwitcher(
              duration: AppDurations.medium2,
              reverse: false,
              transitionBuilder: (child, primary, secondary) {
                return SharedAxisTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  transitionType: SharedAxisTransitionType.horizontal,
                  fillColor: Theme.of(context).colorScheme.surface,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(routeIndex),
                child: _tabPages[routeIndex],
              ),
            )
          else
            widget.child,
          if (showingTab)
            const Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: 96,
              child: UploadOverlay(),
            ),
          if (showingTab)
            const Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(child: FolderToastOverlay()),
            ),
        ],
      ),
      bottomNavigationBar: showingTab
          ? NavigationBar(
              selectedIndex: routeIndex.clamp(0, _tabPaths.length - 1),
              onDestinationSelected: _handleDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Drive',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Photos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_border_rounded),
                  selectedIcon: Icon(Icons.star_rounded),
                  label: 'Starred',
                ),
                NavigationDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: 'Shared',
                ),
              ],
            )
          : null,
    );
  }

  int _tabIndexFor(String location) {
    return _tabPaths.indexWhere(location.startsWith);
  }

  void _handleDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    context.go(_tabPaths[index]);
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
