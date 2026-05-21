import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/community_onboarding_screen.dart';
import 'features/auth/landing_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/drive/drive_screen.dart';
import 'features/drive/folder_screen.dart';
import 'features/drive/starred_screen.dart';
import 'features/file_viewer/file_viewer_screen.dart';
import 'features/photos/photos_filter.dart';
import 'features/photos/photos_screen.dart';
import 'features/photos/photos_viewer/photo_viewer_screen.dart';
import 'features/profile/legal_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/share/my_shares_screen.dart';
import 'features/share/share_detail_screen.dart';
import 'main_shell.dart';
import 'shared/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.loading) return state.matchedLocation == '/' ? null : '/';

      const allowedUnauthRoutes = ['/welcome', '/login', '/privacy', '/terms'];
      final currentRoute = state.matchedLocation;

      if (!auth.isAuthenticated) {
        if (allowedUnauthRoutes.contains(currentRoute)) return null;
        return '/welcome';
      }

      if (auth.needsCommunityOnboarding) {
        return currentRoute == '/community-setup' ? null : '/community-setup';
      }
      if (currentRoute == '/community-setup') return '/drive';

      const authRedirectRoutes = ['/welcome', '/login', '/'];
      if (authRedirectRoutes.contains(currentRoute)) return '/drive';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const LandingScreen()),
      GoRoute(
        path: '/community-setup',
        builder: (_, __) => const CommunityOnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/drive', builder: (_, __) => const DriveScreen()),
          GoRoute(path: '/photos', builder: (_, __) => const PhotosScreen()),
          GoRoute(path: '/starred', builder: (_, __) => const StarredScreen()),
          GoRoute(path: '/shared', builder: (_, __) => const MySharesScreen()),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (_, state) {
          final scrollToStorage =
              state.uri.queryParameters['scrollToStorage'] == 'true';
          return ProfileScreen(scrollToStorage: scrollToStorage);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
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
          filter: PhotosFilterX.fromQuery(state.uri.queryParameters['filter']),
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
});
