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
import 'features/photos/photos_screen.dart';
import 'features/profile/legal_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/theme_controller.dart';
import 'features/upload/upload_sheet.dart';
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
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/folder/:id',
          builder: (_, state) =>
              FolderScreen(folderId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/file/:id',
          builder: (_, state) =>
              FileViewerScreen(fileId: state.pathParameters['id']!),
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

    return MaterialApp.router(
      title: 'TeleDrive',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: theme.mode,
      routerConfig: router,
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

  PageController? _pageController;
  int _selectedIndex = 0;
  bool _isTapAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth.isAuthenticated && auth.telegramConnected == true) {
        ref.read(driveControllerProvider).refresh();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = _tabIndexFor(GoRouterState.of(context).matchedLocation);
    if (index < 0) return;
    _selectedIndex = index;
    _pageController ??= PageController(initialPage: index);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final routeIndex = _tabIndexFor(location);
    final showingTab = routeIndex >= 0;

    if (showingTab && routeIndex != _selectedIndex && !_isTapAnimating) {
      _selectedIndex = routeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageController?.animateToPage(
          routeIndex,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          if (showingTab)
            PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: _handlePageChanged,
              children: _tabPages,
            )
          else
            widget.child,
          if (showingTab)
            const Positioned(
              left: 12,
              right: 12,
              bottom: 86,
              child: UploadMiniOverlay(),
            ),
        ],
      ),
      bottomNavigationBar: showingTab
          ? NavigationBar(
              selectedIndex: _selectedIndex,
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
                  icon: Icon(Icons.star_border),
                  selectedIcon: Icon(Icons.star),
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

  Future<void> _handleDestinationSelected(int index) async {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _isTapAnimating = true;
    await _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _isTapAnimating = false;
    if (!mounted) return;
    context.go(_tabPaths[index]);
  }

  void _handlePageChanged(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
    if (!_isTapAnimating) {
      context.go(_tabPaths[index]);
    }
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
