import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/root_navigator.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/community_onboarding_screen.dart';
import 'features/auth/landing_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/tdlib_session_controller.dart';
import 'features/auth/tdlib_session_screen.dart';
import 'features/drive/drive_screen.dart';
import 'features/drive/folder_screen.dart';
import 'features/drive/starred_screen.dart';
import 'features/file_viewer/file_viewer_screen.dart';
import 'features/photos/photos_filter.dart';
import 'features/photos/photos_screen.dart';
import 'features/photos/photos_viewer/photo_viewer_screen.dart';
import 'features/profile/archive_screen.dart';
import 'features/profile/legal_screen.dart';
import 'features/profile/free_up_space_screen.dart';
import 'features/profile/locked_screen.dart';
import 'features/profile/my_data_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/profile/trash_screen.dart';
import 'features/share/my_shares_screen.dart';
import 'features/share/share_detail_screen.dart';
import 'main_shell.dart';
import 'shared/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);
  final tdlib = ref.read(tdlibSessionControllerProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([auth, tdlib]),
    redirect: (context, state) {
      if (auth.loading) return state.matchedLocation == '/' ? null : '/';

      const allowedUnauthRoutes = ['/welcome', '/login', '/privacy', '/terms'];
      final currentRoute = state.matchedLocation;
      final loginMode = LoginModeX.fromQuery(state.uri.queryParameters['mode']);
      final isAccountLoginMode =
          loginMode == LoginMode.addAccount ||
          loginMode == LoginMode.reauthenticateAccount;

      if (!auth.isAuthenticated) {
        if (allowedUnauthRoutes.contains(currentRoute)) return null;
        return '/welcome';
      }

      if (currentRoute == '/login' && isAccountLoginMode) return null;

      if (!tdlib.isReadyForActiveUser && currentRoute != '/tdlib-session') {
        final returnTo = state.uri.toString();
        return Uri(
          path: '/tdlib-session',
          queryParameters: {
            'mode': 'auto',
            if (returnTo.isNotEmpty && returnTo != '/') 'returnTo': returnTo,
          },
        ).toString();
      }

      if (tdlib.isReadyForActiveUser && auth.needsCommunityOnboarding) {
        return currentRoute == '/community-setup' ? null : '/community-setup';
      }
      if (currentRoute == '/community-setup') return '/drive';

      const authRedirectRoutes = ['/welcome', '/login', '/'];
      if (authRedirectRoutes.contains(currentRoute)) return '/drive';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginScreen(
          mode: LoginModeX.fromQuery(state.uri.queryParameters['mode']),
          returnTo: state.uri.queryParameters['returnTo'],
          targetUserId: int.tryParse(
            state.uri.queryParameters['targetUserId'] ?? '',
          ),
        ),
      ),
      GoRoute(path: '/welcome', builder: (_, __) => const LandingScreen()),
      GoRoute(
        path: '/tdlib-session',
        builder: (_, state) => TdlibSessionScreen(
          mode: state.uri.queryParameters['mode'],
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
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
        pageBuilder: (context, state) {
          final scrollToStorage =
              state.uri.queryParameters['scrollToStorage'] == 'true';
          return CupertinoPage(
            key: state.pageKey,
            child: ProfileScreen(scrollToStorage: scrollToStorage),
          );
        },
      ),
      GoRoute(
        path: '/profile/my-data',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const MyDataScreen()),
      ),
      GoRoute(
        path: '/profile/free-up-space',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const FreeUpSpaceScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/settings/trash',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const TrashScreen()),
      ),
      GoRoute(
        path: '/settings/archive',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const ArchiveScreen()),
      ),
      GoRoute(
        path: '/settings/locked',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const LockedScreen()),
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
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const LegalScreen(kind: LegalKind.privacy),
        ),
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const LegalScreen(kind: LegalKind.terms),
        ),
      ),
    ],
  );
});
