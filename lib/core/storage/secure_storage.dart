import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../../models/account_vault.dart';
import '../../models/auth_user.dart';

class SecureStorageService {
  SecureStorageService();

  static const _tokenKey = 'teledrive_auth_token';
  static const _userKey = 'teledrive_auth_user';
  static const _accountVaultKey = 'teledrive_account_vault_v1';
  static const _tdlibKeyPrefix = 'teledrive_tdlib_key_v1';
  static const _pendingTelegramCommitsPrefix =
      'teledrive_pending_tdlib_commits_v1';
  static const _telegramCloudPasswordPrefix = 'telegram_cloud_password_v1';
  final _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<AuthUser?> readUser() async {
    final value = await _storage.read(key: _userKey);
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      return AuthUser.fromMeJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AuthUser user) {
    return _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<AccountVault> readAccountVault() async {
    final value = await _storage.read(key: _accountVaultKey);
    if (value == null || value.isEmpty) return const AccountVault.empty();
    try {
      final json = jsonDecode(value);
      if (json is! Map) return const AccountVault.empty();
      return AccountVault.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return const AccountVault.empty();
    }
  }

  Future<void> saveAccountVault(AccountVault vault) {
    return _storage.write(
      key: _accountVaultKey,
      value: jsonEncode(vault.toJson()),
    );
  }

  Future<void> clearAccountVault() async {
    await _storage.delete(key: _accountVaultKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<String?> readTdlibKey(String scope) =>
      _storage.read(key: '${_tdlibKeyPrefix}_$scope');

  Future<void> saveTdlibKey(String scope, String value) =>
      _storage.write(key: '${_tdlibKeyPrefix}_$scope', value: value);

  Future<String?> readPendingTelegramCommits(String scope) =>
      _storage.read(key: '${_pendingTelegramCommitsPrefix}_$scope');

  Future<void> savePendingTelegramCommits(String scope, String value) =>
      _storage.write(
        key: '${_pendingTelegramCommitsPrefix}_$scope',
        value: value,
      );

  Future<void> clearPendingTelegramCommits(String scope) =>
      _storage.delete(key: '${_pendingTelegramCommitsPrefix}_$scope');

  Future<void> saveTelegramCloudPassword({
    required int backendUserId,
    required int telegramUserId,
    required String password,
  }) {
    return _storage.write(
      key: _cloudPasswordKey(backendUserId, telegramUserId),
      value: password,
    );
  }

  Future<String?> readTelegramCloudPassword({
    required int backendUserId,
    required int telegramUserId,
  }) {
    return _storage.read(
      key: _cloudPasswordKey(backendUserId, telegramUserId),
    );
  }

  Future<void> deleteTelegramCloudPassword({
    required int backendUserId,
    required int telegramUserId,
  }) {
    return _storage.delete(
      key: _cloudPasswordKey(backendUserId, telegramUserId),
    );
  }

  Future<void> deleteAllTelegramCloudPasswordsForUser(int backendUserId) async {
    final all = await _storage.readAll();
    final prefix =
        '$_telegramCloudPasswordPrefix:${_apiBaseUrlHash()}:$backendUserId:';
    for (final key in all.keys.where((k) => k.startsWith(prefix)).toList()) {
      await _storage.delete(key: key);
    }
  }

  String _cloudPasswordKey(int backendUserId, int telegramUserId) {
    return '$_telegramCloudPasswordPrefix:${_apiBaseUrlHash()}:$backendUserId:$telegramUserId';
  }

  String _apiBaseUrlHash() {
    final value = AppConfig.apiBaseUrl;
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
