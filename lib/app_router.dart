import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/root_navigator.dart';
import 'features/app_update/app_update_screen.dart';
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
import 'features/profile/widgets/account_bottom_sheet.dart';
import 'features/profile/trash_screen.dart';
import 'features/project/changelog_screen.dart';
import 'features/project/project_screen.dart';
import 'features/share/my_shares_screen.dart';
import 'features/share/share_detail_screen.dart';
import 'main_shell.dart';
import 'shared/splash_screen.dart';
import 'widgets/search_keyboard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);
  final tdlib = ref.read(tdlibSessionControllerProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [SearchKeyboardObserver()],
    initialLocation: '/',
    refreshListenable: Listenable.merge([auth, tdlib]),
    redirect: (context, state) {
      if (auth.loading) return state.matchedLocation == '/' ? null : '/';

      const allowedUnauthRoutes = ['/welcome', '/login', '/privacy', '/terms'];
      const tdlibEscapeRoutes = [
        '/welcome',
        '/login',
        '/privacy',
        '/terms',
        '/tdlib-session',
      ];
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

      if (tdlib.requiresAuthorizationFlow) {
        if (tdlibEscapeRoutes.contains(currentRoute)) return null;
        final returnTo = state.uri.toString();
        final pendingMode = auth.pendingTdlibMode?.name ?? 'normalLogin';
        final previousUserId = auth.pendingPreviousUserId;
        return Uri(
          path: '/tdlib-session',
          queryParameters: {
            'mode': 'auto',
            'source': pendingMode,
            if (returnTo.isNotEmpty && returnTo != '/') 'returnTo': returnTo,
            if (previousUserId != null) 'previousUserId': '$previousUserId',
          },
        ).toString();
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
        builder: (_, state) {
          final sourceParam = state.uri.queryParameters['source'];
          final source = sourceParam == null
              ? null
              : PendingTdlibMode.values.firstWhere(
                  (mode) => mode.name == sourceParam,
                  orElse: () => PendingTdlibMode.normalLogin,
                );
          final previousUserIdParam =
              state.uri.queryParameters['previousUserId'];
          return TdlibSessionScreen(
            mode: state.uri.queryParameters['mode'],
            source: source,
            returnTo: state.uri.queryParameters['returnTo'],
            previousUserId: previousUserIdParam == null
                ? null
                : int.tryParse(previousUserIdParam),
          );
        },
      ),
      GoRoute(
        path: '/community-setup',
        builder: (_, __) => const CommunityOnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/drive', builder: (_, __) => const DriveScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/photos',
                builder: (_, __) => const PhotosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/starred',
                builder: (_, __) => const StarredScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shared',
                builder: (_, __) => const MySharesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const AccountBottomSheet(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) {
          final scrollToStorage =
              state.uri.queryParameters['scrollToStorage'] == 'true';
          return MaterialPage(
            key: state.pageKey,
            child: ProfileScreen(scrollToStorage: scrollToStorage),
          );
        },
      ),
      GoRoute(
        path: '/profile/my-data',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const MyDataScreen()),
      ),
      GoRoute(
        path: '/profile/free-up-space',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const FreeUpSpaceScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/settings/app-update',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const AppUpdateScreen()),
      ),
      GoRoute(
        path: '/settings/project',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const ProjectScreen()),
      ),
      GoRoute(
        path: '/settings/project/changelog',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const ChangelogScreen()),
      ),
      GoRoute(
        path: '/settings/trash',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const TrashScreen()),
      ),
      GoRoute(
        path: '/settings/archive',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const ArchiveScreen()),
      ),
      GoRoute(
        path: '/settings/locked',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const LockedScreen()),
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
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const LegalScreen(kind: LegalKind.privacy),
        ),
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const LegalScreen(kind: LegalKind.terms),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
