import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/features/auth/login_screen.dart';
import 'platform_folder_ui_test.dart' show capture;

const _challengeToken = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';

class _FixtureAuth extends AuthRepository {
  _FixtureAuth() : super(ApiClient(), SecureStorageService());
  String? phone, code, password;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> start(String value) async {
    phone = value;
    return pending == null
        ? {'attempt_id': 42, 'attempt_token': _challengeToken}
        : pending!.future;
  }

  @override
  Future<Map<String, dynamic>> verifyCode(
    int attemptId,
    String attemptToken,
    String value,
  ) async {
    expect(attemptId, 42);
    expect(attemptToken, _challengeToken);
    code = value;
    return {'status': 'requires_2fa'};
  }

  @override
  Future<Map<String, dynamic>> verifyPassword(
    int attemptId,
    String attemptToken,
    String value,
  ) async {
    expect(attemptId, 42);
    expect(attemptToken, _challengeToken);
    password = value;
    return {};
  }
}

Future<_FixtureAuth> _pumpLogin(
  WidgetTester tester,
  TargetPlatform platform, {
  bool dark = false,
  double width = 390,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  debugDefaultTargetPlatformOverride = platform;
  final theme = buildTheme(
    AppBrand.scheme(dark ? Brightness.dark : Brightness.light),
  ).copyWith(platform: platform);
  debugDefaultTargetPlatformOverride = null;
  final repo = _FixtureAuth();
  addTearDown(() => repo.api.dio.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: RepaintBoundary(
        key: const ValueKey('preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  setUp(() => dotenv.testLoad(fileInput: ''));
  setUpAll(() async {
    for (final family in [
      'Inter',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      'Roboto',
      '.SF Pro Text',
      '.SF Pro Display',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final dark in [false, true]) {
      testWidgets('complete login form states $platform dark=$dark', (
        tester,
      ) async {
        final repo = await _pumpLogin(tester, platform, dark: dark);
        final name = '${platform.name}-${dark ? 'dark' : 'light'}';
        await capture(tester, 'login-phone-$name');
        expect(
          find.byType(
            platform == TargetPlatform.iOS ? CupertinoTextField : TextField,
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Please enter your phone number'), findsOneWidget);
        expect(repo.phone, isNull);
        await tester.enterText(find.byType(EditableText), '9876543210');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(repo.phone, '+919876543210');
        expect(find.textContaining('Check your'), findsOneWidget);
        await capture(tester, 'login-code-$name');
        await tester.enterText(find.byType(EditableText), '123456');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
        expect(repo.code, '123456');
        expect(find.byTooltip('Show password'), findsOneWidget);
        await capture(tester, 'login-password-$name');
        await tester.enterText(find.byType(EditableText), 'fixture-password');
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).obscureText,
          isTrue,
        );
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).obscureText,
          isFalse,
        );
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(repo.password, 'fixture-password');
        await tester.tap(find.text('Start over'));
        await tester.pumpAndSettle();
        expect(find.text('Continue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('login country picker and keyboard at large text $platform', (
      tester,
    ) async {
      await _pumpLogin(tester, platform, width: 320, scale: 2, keyboard: 260);
      await tester.ensureVisible(find.text('India'));
      await tester.tap(find.text('India'));
      await tester.pumpAndSettle();
      final search = find.byType(EditableText).last;
      await tester.enterText(search, 'United Kingdom');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'United Kingdom'));
      await tester.pumpAndSettle();
      expect(find.textContaining('+44'), findsWidgets);
      expect(find.text('🇬🇧'), findsOneWidget);
      expect(find.text('GB'), findsNothing);
      expect(find.text('Choose a country'), findsNothing);
      await tester.enterText(find.byType(EditableText), '12345678');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('late login response is safe after dismissal', (tester) async {
    final repo = await _pumpLogin(tester, TargetPlatform.iOS);
    repo.pending = Completer<Map<String, dynamic>>();
    await tester.enterText(find.byType(EditableText), '9876543210');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    repo.pending!.complete({
      'attempt_id': 42,
      'attempt_token': _challengeToken,
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
