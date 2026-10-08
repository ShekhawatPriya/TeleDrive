import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';

SavedAccount account(int id) => SavedAccount(
  userId: id,
  telegramId: id + 100,
  firstName: 'User $id',
  token: 'token-$id',
  addedAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
  photoUrl: 'https://fixture.test/$id?photo=1',
  localPhotoPath: '/fixture/${id}_${id + 100}_old.jpg',
);

class _Repository extends AuthRepository {
  _Repository() : super(ApiClient(), SecureStorageService());
  final pending = <int, Completer<AuthUser>>{};
  final tokens = <String>[];
  final activeUsers = <AuthUser>[];
  int downloads = 0;
  @override
  bool isExpired(String token) => false;
  @override
  Future<AuthUser> fetchAccountProfile(SavedAccount account) {
    tokens.add(account.token);
    return (pending[account.userId] ??= Completer<AuthUser>()).future;
  }

  @override
  Future<void> saveVault(AccountVault vault) async {}
  @override
  Future<void> saveActiveUser(AuthUser user) async => activeUsers.add(user);
  @override
  Future<String?> cacheProfilePhoto(AuthUser user) async {
    downloads++;
    return '/fixture/${user.userId}_${user.telegramId}_new.jpg';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repo;
  late AuthController auth;
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://fixture.test/api');
    repo = _Repository();
    auth = AuthController(repo, SecureStorageService())
      ..vault = AccountVault(
        accounts: [account(1), account(2)],
        activeUserId: 1,
      )
      ..user = account(1).toAuthUser()
      ..token = account(1).token
      ..loading = false;
  });
  tearDown(() {
    auth.dispose();
    repo.api.dio.close();
  });

  test(
    'unchanged main photo coalesces refresh and downloads no bytes',
    () async {
      final first = auth.refreshProfile(), second = auth.refreshProfile();
      expect(repo.tokens, ['token-1']);
      repo.pending[1]!.complete(account(1).toAuthUser());
      await Future.wait([first, second]);
      expect(repo.downloads, 0);
      expect(auth.activeAccount!.localPhotoPath, contains('old'));
    },
  );

  test(
    'changed main photo updates primary and secondary without switching',
    () async {
      final active = auth.refreshProfile();
      final others = auth.refreshSavedAccountSnapshots();
      repo.pending[1]!.complete(
        account(
          1,
        ).toAuthUser().copyWith(photoUrl: 'https://fixture.test/1?photo=4'),
      );
      repo.pending[2]!.complete(
        account(
          2,
        ).toAuthUser().copyWith(photoUrl: 'https://fixture.test/2?photo=3'),
      );
      await Future.wait([active, others]);
      expect(repo.tokens, ['token-1', 'token-2']);
      expect(repo.downloads, 2);
      expect(auth.vault.activeUserId, 1);
      expect(auth.token, 'token-1');
      expect(auth.user!.photoUrl, endsWith('photo=4'));
      expect(auth.vault.accountByUserId(2)!.photoUrl, endsWith('photo=3'));
      expect(repo.activeUsers.map((u) => u.userId), [1]);
    },
  );

  test(
    'confirmed removal clears both remote and local saved avatars',
    () async {
      final refresh = auth.refreshProfile();
      repo.pending[1]!.complete(
        account(1).toAuthUser().copyWith(clearPhotoUrl: true),
      );
      await refresh;
      expect(auth.user!.photoUrl, isNull);
      expect(auth.activeAccount!.resolvedPhotoUrl, isNull);
      expect(auth.activeAccount!.localPhotoPath, isNull);
      expect(repo.downloads, 0);
    },
  );

  test(
    'late active response cannot overwrite another active identity',
    () async {
      final refresh = auth.refreshProfile();
      auth.vault = auth.vault.upsert(account(2), makeActive: true);
      auth.user = account(2).toAuthUser();
      auth.token = 'token-2';
      repo.pending[1]!.complete(
        account(1).toAuthUser().copyWith(firstName: 'Stale'),
      );
      await refresh;
      expect(auth.user!.userId, 2);
      expect(repo.activeUsers, isEmpty);
    },
  );

  test('late secondary response cannot resurrect a removed account', () async {
    final refresh = auth.refreshSavedAccountSnapshots();
    auth.vault = auth.vault.remove(2);
    repo.pending[2]!.complete(account(2).toAuthUser());
    await refresh;
    expect(auth.vault.accountByUserId(2), isNull);
    expect(repo.downloads, 0);
  });
}
