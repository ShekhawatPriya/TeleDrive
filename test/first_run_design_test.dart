import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/features/auth/community_onboarding_screen.dart';
import 'package:flutter_m_fsdk/features/auth/landing_screen.dart';
import 'package:flutter_m_fsdk/features/auth/models/community_onboarding.dart';
import 'package:flutter_m_fsdk/features/auth/login_screen.dart';
import 'package:flutter_m_fsdk/features/auth/tdlib_auto_authorization_models.dart';
import 'package:flutter_m_fsdk/features/auth/tdlib_session_controller.dart';
import 'package:flutter_m_fsdk/features/auth/tdlib_session_screen.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/features/project/changelog_controller.dart';
import 'package:flutter_m_fsdk/features/project/changelog_screen.dart';
import 'package:flutter_m_fsdk/features/project/github_release_models.dart';

/// Rendered previews of everything a new user sees before Drive, and of the
/// release notes, on a 402-point iPhone with its safe areas. Write them with
/// `--dart-define=WRITE_UI_PREVIEWS=true`; they land in `build/modernization/`.
final _releases = GithubRelease.parseList(
  jsonDecode(File('test/fixtures/github_releases.json').readAsStringSync()),
);

class _Changelog extends ChangeNotifier implements ChangelogController {
  @override
  ChangelogState get state =>
      ChangelogState(hasLoadedOnce: true, releases: _releases);
  @override
  Future<void> load({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthRepository {
  _Auth() : super(ApiClient(), SecureStorageService());
  @override
  Future<Map<String, dynamic>> start(String value) async => {
    'attempt_id': 42,
    'attempt_token': 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
  };
}

final _account = SavedAccount(
  userId: 7,
  telegramId: 7001,
  firstName: 'Priya',
  lastName: 'Shekhawat',
  phoneNumber: '+919876543210',
  token: 'token',
  addedAt: DateTime(2026, 9, 16),
  lastUsedAt: DateTime(2026, 9, 16),
);

class _SignedIn extends ChangeNotifier implements AuthController {
  @override
  bool loading = false;
  @override
  AuthUser? user = const AuthUser(
    userId: 7,
    telegramId: 7001,
    firstName: 'Priya',
    lastName: 'Shekhawat',
  );
  @override
  String? token = 'token';
  @override
  String? pendingCandidatePhone;
  @override
  int? pendingPreviousUserId;
  @override
  int? pendingCandidateTelegramId;
  @override
  PendingTdlibMode? pendingTdlibMode = PendingTdlibMode.normalLogin;
  @override
  List<CommunityTarget> communityTargets = const [
    CommunityTarget(label: 'Channel', name: 'DevsDoCode', kind: 'channel'),
    CommunityTarget(label: 'Group', name: 'DevsDoCode Chat', kind: 'group'),
  ];
  @override
  bool get isAuthenticated => true;
  @override
  SavedAccount? get activeAccount => _account;
  @override
  AccountVault get vault =>
      const AccountVault.empty().upsert(_account, makeActive: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Setup extends ChangeNotifier implements TdlibSessionController {
  _Setup(this.state);
  @override
  TdlibSessionState state;
  @override
  Future<void> authorizeAutomatically({
    required String phoneNumber,
    required int telegramUserId,
    required int backendUserId,
    required PendingTdlibMode mode,
    bool restartOtpWindow = false,
  }) async {}
  @override
  Future<void> retryOtp() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('WRITE_UI_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/modernization/first-run/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget home, {
  bool dark = false,
  double width = 402,
  double height = 874,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  TdlibSessionState? setup,
  bool signedIn = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(
    AppBrand.scheme(dark ? Brightness.dark : Brightness.light),
  ).copyWith(platform: platform);
  debugDefaultTargetPlatformOverride = null;
  final repo = _Auth();
  addTearDown(() => repo.api.dio.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        changelogControllerProvider.overrideWith((_) => _Changelog()),
        if (setup != null || signedIn)
          authControllerProvider.overrideWith((_) => _SignedIn()),
        if (setup != null)
          tdlibSessionControllerProvider.overrideWith((_) => _Setup(setup)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child!),
        ),
        home: home,
      ),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(find.byWidget(home));
    for (final asset in [
      'assets/icon/app_icon.png',
      'assets/icon/app_icon_ios.png',
      'assets/icon/telegram.png',
    ]) {
      await precacheImage(AssetImage(asset), context);
      for (final width in [204, 276]) {
        await precacheImage(
          ResizeImage(AssetImage(asset), width: width),
          context,
        );
      }
    }
  });
  if (setup == null) {
    await tester.pumpAndSettle();
  } else {
    // The activity indicator spins indefinitely; let transitions finish.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 140));
    }
  }
}

void main() {
  setUp(() => dotenv.testLoad(fileInput: ''));
  setUpAll(() async {
    for (final family in [
      'Inter',
      'Roboto',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF Pro Text',
      '.SF Pro Display',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    }
    await (FontLoader('JetBrains Mono')
          ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Variable.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('welcome $theme', (tester) async {
      await pumpScreen(tester, const LandingScreen(), dark: dark);
      expect(find.text('Continue with Telegram'), findsOneWidget);
      await capture(tester, 'welcome-$theme');
    });

    testWidgets('sign-in phone and code $theme', (tester) async {
      await pumpScreen(tester, const LoginScreen(), dark: dark);
      await capture(tester, 'login-phone-$theme');
      await tester.enterText(find.byType(CupertinoTextField), '98765 43210');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await capture(tester, 'login-code-$theme');
    });

    for (final entry in <(String, TdlibAutoAuthorizationState)>[
      (
        'waiting',
        const TdlibAutoAuthorizationState(
          stage: TdlibAutoAuthStage.waitingForCode,
          progressPercent: 45,
          otpSecondsRemaining: 42,
          subtitle: 'Reading the sign-in code Telegram just sent.',
        ),
      ),
      (
        'code',
        const TdlibAutoAuthorizationState(
          stage: TdlibAutoAuthStage.manualCodeRequired,
          progressPercent: 45,
          subtitle: 'Enter the code from your Telegram app.',
        ),
      ),
      (
        'failed',
        const TdlibAutoAuthorizationState(
          stage: TdlibAutoAuthStage.failed,
          progressPercent: 32,
          error: 'Telegram did not confirm this account. Try again.',
        ),
      ),
      (
        'done',
        const TdlibAutoAuthorizationState(
          stage: TdlibAutoAuthStage.authorized,
          progressPercent: 100,
        ),
      ),
    ]) {
      testWidgets('device setup ${entry.$1} $theme', (tester) async {
        await pumpScreen(
          tester,
          const TdlibSessionScreen(),
          dark: dark,
          setup: TdlibSessionState(
            status: TdlibSessionStatus.authorizationRequired,
            auto: entry.$2,
          ),
        );
        await capture(tester, 'setup-${entry.$1}-$theme');
        if (entry.$1 == 'code') {
          await tester.tap(find.text('Enter Code Manually').last);
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 140));
          }
          await capture(tester, 'setup-code-entry-$theme');
        }
        // Leave before the success navigation delay elapses.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('sign in again $theme', (tester) async {
      await pumpScreen(
        tester,
        const LoginScreen(
          mode: LoginMode.reauthenticateAccount,
          targetUserId: 7,
        ),
        dark: dark,
        signedIn: true,
      );
      expect(find.text('Sign In Again'), findsOneWidget);
      expect(find.textContaining('Priya Shekhawat'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      await capture(tester, 'login-again-$theme');
    });

    testWidgets('community $theme', (tester) async {
      await pumpScreen(
        tester,
        const CommunityOnboardingScreen(),
        dark: dark,
        signedIn: true,
      );
      expect(find.text('Continue'), findsOneWidget);
      await capture(tester, 'community-$theme');
    });

    testWidgets('what’s new $theme', (tester) async {
      await pumpScreen(
        tester,
        const ChangelogScreen(),
        dark: dark,
        height: 2400,
      );
      await capture(tester, 'whats-new-$theme');
    });

    testWidgets('release page $theme', (tester) async {
      await pumpScreen(
        tester,
        const ChangelogScreen(),
        dark: dark,
        height: 1900,
      );
      final row = find.text('Version 3.1.3');
      await tester.scrollUntilVisible(row, 300);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await capture(tester, 'release-3.1.3-$theme');
    });
  }

  // A small phone at 200% text: nothing overflows or clips.
  for (final entry in <(String, Widget, bool)>[
    ('welcome', const LandingScreen(), false),
    ('login', const LoginScreen(), false),
    ('community', const CommunityOnboardingScreen(), true),
    ('whats-new', const ChangelogScreen(), false),
  ]) {
    testWidgets('${entry.$1} fits 320 points at 200% text', (tester) async {
      await pumpScreen(
        tester,
        entry.$2,
        width: 320,
        height: 640,
        scale: 2,
        signedIn: entry.$3,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, '${entry.$1}-large-text');
    });
  }
  testWidgets('device setup fits 320 points at 200% text', (tester) async {
    await pumpScreen(
      tester,
      const TdlibSessionScreen(),
      width: 320,
      height: 640,
      scale: 2,
      setup: const TdlibSessionState(
        status: TdlibSessionStatus.authorizationRequired,
        auto: TdlibAutoAuthorizationState(
          stage: TdlibAutoAuthStage.failed,
          progressPercent: 32,
          error: 'Telegram did not confirm this account. Try again.',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'setup-large-text');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
