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
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = [
      '/drive',
      '/photos',
      '/starred',
      '/shared',
      '/profile',
    ].indexWhere(location.startsWith);
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          const Positioned(
            left: 12,
            right: 12,
            bottom: 86,
            child: UploadMiniOverlay(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(
          ['/drive', '/photos', '/starred', '/shared', '/profile'][i],
        ),
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
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
