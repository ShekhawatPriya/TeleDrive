import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';

SavedAccount _account(int id) => SavedAccount(
  userId: id,
  telegramId: id * 10,
  firstName: 'Account $id',
  token: 'fixture-$id',
  addedAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
);

class _Repository extends AuthRepository {
  _Repository() : super(ApiClient(), SecureStorageService());
  AccountVault saved = const AccountVault.empty();
  Completer<AuthBootstrapResult>? snapshot;
  Completer<String?>? photo;
  Completer<AuthUser>? profile;
  Completer<void>? photoDeletion;
  Completer<AuthBootstrapResult>? loginResponse;
  Completer<void>? pendingWrite;
  int photoCalls = 0;
  int writes = 0;
  AuthUser? savedUser;

  @override
  bool isExpired(String token) => false;
  @override
  Future<AuthBootstrapResult> bootstrapWithToken(
    String token, {
    bool includeDrive = true,
  }) async {
    if (!includeDrive && snapshot != null) return snapshot!.future;
    if (token == 'fixture-3' && loginResponse != null)
      return loginResponse!.future;
    final id = int.parse(token.split('-').last);
    return AuthBootstrapResult(
      user: _account(id).toAuthUser(),
      telegramConnected: true,
    );
  }

  @override
  Future<String?> cacheProfilePhoto(AuthUser user) async {
    photoCalls++;
    return photo?.future;
  }

  @override
  Future<void> saveVault(AccountVault vault) async {
    writes++;
    final wait = pendingWrite;
    pendingWrite = null;
    if (wait != null) await wait.future;
    saved = vault;
  }

  @override
  Future<void> saveActiveUser(AuthUser user) async => savedUser = user;
  @override
  Future<void> deleteCachedProfilePhoto(int userId) async {
    if (photoDeletion != null) await photoDeletion!.future;
  }

  @override
  Future<void> clearAllAuthStorage() async {
    saved = const AccountVault.empty();
    savedUser = null;
    api.setToken(null);
  }

  @override
  Future<AuthUser> fetchProfile({AuthUser? current}) => profile!.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repo;
  late AuthController auth;
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://backend.example.test/api');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    repo = _Repository();
    auth = AuthController(repo, SecureStorageService());
    auth.vault = AccountVault(
      accounts: [_account(1), _account(2)],
      activeUserId: 1,
    );
    auth.user = _account(1).toAuthUser();
    auth.token = _account(1).token;
    repo.api.setToken(auth.token);
    repo.saved = auth.vault;
  });
  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    auth.dispose();
    repo.api.dio.close();
  });

  test(
    'late snapshot cannot reinsert an account after switch and removal',
    () async {
      repo.snapshot = Completer<AuthBootstrapResult>();
      final refresh = auth.refreshSavedAccountSnapshots();
      await auth.switchToAccount(2);
      await auth.removeAccountFromDevice(2);
      repo.snapshot!.complete(
        AuthBootstrapResult(
          user: _account(2).toAuthUser(),
          telegramConnected: true,
        ),
      );
      await refresh;
      expect(auth.user?.userId, 1);
      expect(auth.vault.accountByUserId(2), isNull);
      expect(repo.saved.accountByUserId(2), isNull);
    },
  );

  test('removal during avatar await also discards the snapshot', () async {
    repo.photo = Completer<String?>();
    final refresh = auth.refreshSavedAccountSnapshots();
    await Future<void>.delayed(Duration.zero);
    expect(repo.photoCalls, 1);
    await auth.removeAccountFromDevice(2);
    repo.photo!.complete('/fixture/old-avatar.jpg');
    await refresh;
    expect(auth.vault.accountByUserId(2), isNull);
    expect(repo.saved.accountByUserId(2), isNull);
  });

  test('sign-out invalidates an outstanding snapshot', () async {
    repo.snapshot = Completer<AuthBootstrapResult>();
    final refresh = auth.refreshSavedAccountSnapshots();
    await auth.signOutAll();
    repo.snapshot!.complete(
      AuthBootstrapResult(
        user: _account(2).toAuthUser(),
        telegramConnected: true,
      ),
    );
    await refresh;
    expect(auth.isAuthenticated, isFalse);
    expect(auth.vault.accounts, isEmpty);
    expect(repo.saved.accounts, isEmpty);
  });

  test(
    'removal persists after an already-started slow snapshot write',
    () async {
      final write = Completer<void>();
      repo.pendingWrite = write;
      final refresh = auth.refreshSavedAccountSnapshots();
      await Future<void>.delayed(Duration.zero);
      expect(repo.writes, 1);
      final removal = auth.removeAccountFromDevice(2);
      await Future<void>.delayed(Duration.zero);
      expect(repo.writes, 1, reason: 'Removal queues behind the older write.');
      write.complete();
      await Future.wait([refresh, removal]);
      expect(repo.saved.accountByUserId(2), isNull);
    },
  );

  test(
    'late profile response cannot replace a newly selected identity',
    () async {
      repo.profile = Completer<AuthUser>();
      final refresh = auth.refreshProfile();
      await auth.switchToAccount(2);
      repo.profile!.complete(_account(1).toAuthUser());
      await refresh;
      expect(auth.user?.userId, 2);
      expect(repo.savedUser?.userId, 2);
      expect(repo.api.token, 'fixture-2');
    },
  );

  test('current snapshot updates still persist', () async {
    await auth.refreshSavedAccountSnapshots();
    expect(auth.vault.accountByUserId(2), isNotNull);
    expect(repo.saved.accountByUserId(2), isNotNull);
    expect(auth.user?.userId, 1);
  });

  test('late account removal cannot cancel a newer login', () async {
    repo.photoDeletion = Completer<void>();
    final removal = auth.removeAccountFromDevice(1);
    await Future<void>.delayed(Duration.zero);
    repo.loginResponse = Completer<AuthBootstrapResult>();
    final login = auth.login('fixture-3');
    repo.photoDeletion!.complete();
    await removal;
    repo.loginResponse!.complete(
      AuthBootstrapResult(
        user: _account(3).toAuthUser(),
        telegramConnected: true,
      ),
    );
    await login;
    expect(auth.user?.userId, 3);
    expect(repo.saved.accountByUserId(1), isNull);
    expect(repo.saved.activeUserId, 3);
  });
}
