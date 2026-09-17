import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';

class _Repository extends AuthRepository {
  _Repository() : super(ApiClient(), SecureStorageService());

  final response = Completer<AuthBootstrapResult>();
  final photo = Completer<String?>();
  int photoRequests = 0;
  final savedVaults = <AccountVault>[];
  final account = SavedAccount(
    userId: 1,
    telegramId: 42,
    firstName: 'Fixture',
    token: 'fixture',
    addedAt: DateTime(2026),
    lastUsedAt: DateTime(2026),
    localPhotoPath: '/fixture/1_42_photo.jpg',
  );

  @override
  Future<AccountVault> storedVault() async =>
      AccountVault(accounts: [account], activeUserId: 1);
  @override
  bool isExpired(String token) => false;
  @override
  Future<AuthBootstrapResult> bootstrapWithToken(
    String token, {
    bool includeDrive = true,
  }) => response.future;
  @override
  Future<void> saveVault(AccountVault vault) async => savedVaults.add(vault);
  @override
  Future<void> saveActiveUser(AuthUser user) async {}
  @override
  Future<String?> cacheProfilePhoto(AuthUser user) {
    photoRequests++;
    return photo.future;
  }
}

const _user = AuthUser(
  userId: 1,
  telegramId: 42,
  firstName: 'Fixture',
  photoUrl: 'https://example.test/current-photo',
);
const _bootstrap = AuthBootstrapResult(
  user: _user,
  telegramConnected: true,
  communityJoinStatus: 'joined',
  featureFlags: BackendFeatureFlags(directTelegramUploadEnabled: true),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repo;
  late AuthController auth;
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    repo = _Repository();
    auth = AuthController(repo, SecureStorageService());
  });
  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    auth.dispose();
    repo.api.dio.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  test(
    'startup still waits for server validation but never for avatar download',
    () async {
      final startup = auth.bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(auth.loading, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(repo.api.token, isNull);
      repo.response.complete(_bootstrap);
      await startup.timeout(const Duration(seconds: 1));
      expect(auth.loading, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(repo.photoRequests, 0);
      expect(auth.user?.photoUrl, _user.photoUrl);
      expect(auth.activeAccount?.localPhotoPath, repo.account.localPhotoPath);
      expect(auth.featureFlags.directTelegramUploadEnabled, isTrue);
      expect(repo.api.token, 'fixture');
    },
  );

  test('server rejection still marks the account for login', () async {
    final startup = auth.bootstrap();
    final request = RequestOptions(path: '/frontend/bootstrap');
    repo.response.completeError(
      DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401),
      ),
    );
    await startup;
    expect(auth.isAuthenticated, isFalse);
    expect(repo.api.token, isNull);
    expect(auth.vault.accounts.single.tokenStatus, TokenStatus.needsLogin);
    expect(repo.photoRequests, 0);
  });

  test('mismatched identity cannot become the active session', () async {
    final startup = auth.bootstrap();
    repo.response.complete(
      const AuthBootstrapResult(
        user: AuthUser(userId: 2, telegramId: 99, firstName: 'Other'),
        telegramConnected: true,
      ),
    );
    await startup;
    expect(auth.isAuthenticated, isFalse);
    expect(repo.api.token, isNull);
    expect(auth.vault.accounts.single.tokenStatus, TokenStatus.needsLogin);
  });

  test('explicit login keeps its existing photo-cache behavior', () async {
    final login = auth.login('fixture');
    repo.response.complete(_bootstrap);
    await Future<void>.delayed(Duration.zero);
    expect(repo.photoRequests, 1);
    expect(auth.isAuthenticated, isFalse);
    repo.photo.complete('/fixture/1_42_new.jpg');
    await login;
    expect(auth.isAuthenticated, isTrue);
  });
}
