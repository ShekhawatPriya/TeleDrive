import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/core/utils/jwt.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';

/// An unsigned JWT-shaped token; the client only reads its claims.
String jwtFor(int userId, {required int issuedDaysAgo, int lifetimeDays = 30}) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final iat = now - issuedDaysAgo * 86400;
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': '$userId', 'iat': iat, 'exp': iat + lifetimeDays * 86400})}'
      '.sig';
}

SavedAccount account(int id, String token) => SavedAccount(
  userId: id,
  telegramId: id + 100,
  firstName: 'User $id',
  token: token,
  addedAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
);

class _Repository extends AuthRepository {
  _Repository() : super(ApiClient(), SecureStorageService());
  final renewed = <int>[];
  int? failWith;
  bool unsupported = false;

  @override
  Future<String?> renewToken(SavedAccount account) async {
    if (unsupported) return null;
    if (failWith != null) {
      final options = RequestOptions(path: '/telegram/auth/renew');
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: failWith),
      );
    }
    renewed.add(account.userId);
    return jwtFor(account.userId, issuedDaysAgo: 0);
  }

  @override
  Future<AuthUser> fetchAccountProfile(SavedAccount account) async =>
      account.toAuthUser();
  @override
  Future<void> saveVault(AccountVault vault) async {}
  @override
  Future<String?> cacheProfilePhoto(AuthUser user) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isJwtDueForRenewal', () {
    test('waits for a third of the lifetime', () {
      expect(isJwtDueForRenewal(jwtFor(1, issuedDaysAgo: 2)), isFalse);
      expect(isJwtDueForRenewal(jwtFor(1, issuedDaysAgo: 11)), isTrue);
    });
    test('never renews an expired or malformed token', () {
      expect(isJwtDueForRenewal(jwtFor(1, issuedDaysAgo: 31)), isFalse);
      expect(isJwtDueForRenewal('not-a-token'), isFalse);
    });
  });

  group('saved account renewal', () {
    late _Repository repo;
    late AuthController auth;
    final activeOld = jwtFor(1, issuedDaysAgo: 20);
    final savedOld = jwtFor(2, issuedDaysAgo: 25);
    final savedFresh = jwtFor(3, issuedDaysAgo: 1);

    setUp(() {
      dotenv.testLoad(fileInput: 'API_BASE_URL=https://fixture.test/api');
      repo = _Repository();
      auth = AuthController(repo, SecureStorageService())
        ..vault = AccountVault(
          accounts: [
            account(1, activeOld),
            account(2, savedOld),
            account(3, savedFresh),
          ],
          activeUserId: 1,
        )
        ..user = account(1, activeOld).toAuthUser()
        ..token = activeOld
        ..loading = false;
    });
    tearDown(() {
      auth.dispose();
      repo.api.dio.close();
    });

    test('renews aging tokens, including the active one, and keeps the '
        'active account', () async {
      await auth.refreshSavedAccountSnapshots();
      expect(repo.renewed, [1, 2]);
      expect(auth.vault.activeUserId, 1);
      expect(auth.token, isNot(activeOld));
      expect(auth.token, auth.vault.accountByUserId(1)!.token);
      expect(auth.vault.accountByUserId(2)!.token, isNot(savedOld));
      expect(auth.vault.accountByUserId(3)!.token, savedFresh);
      expect(auth.vault.accounts.every((a) => !a.needsSignIn), isTrue);
    });

    test(
      'a rejected token asks for sign-in instead of failing later',
      () async {
        repo.failWith = 401;
        await auth.refreshSavedAccountSnapshots();
        expect(auth.vault.accountByUserId(2)!.needsSignIn, isTrue);
      },
    );

    test('a server without renewal leaves tokens untouched', () async {
      repo.unsupported = true;
      await auth.refreshSavedAccountSnapshots();
      expect(auth.vault.accountByUserId(2)!.token, savedOld);
      expect(auth.token, activeOld);
    });
  });
}
