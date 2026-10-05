import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/stable_hash.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/jwt.dart';
import '../../models/account_vault.dart';
import '../../models/auth_user.dart';
import '../drive/drive_repository.dart';
import 'tdlib_auto_authorization_models.dart';
import 'models/community_onboarding.dart';
import 'auth_repository_models.dart';

export 'auth_repository_models.dart';

part 'auth_repository_helpers.dart';

class AuthRepository {
  AuthRepository(this.api, this.storage);

  final ApiClient api;
  final SecureStorageService storage;

  Future<String?> storedToken() => storage.readToken();
  Future<AuthUser?> storedUser() => storage.readUser();
  Future<AccountVault> storedVault() => storage.readAccountVault();
  Future<void> saveVault(AccountVault vault) => storage.saveAccountVault(vault);

  bool isExpired(String token) => isJwtExpired(token);
  AuthUser? decode(String token) => decodeJwtUser(token);

  AuthUser? userFromAuthPayload(Map<String, dynamic> data) {
    try {
      return _withLoadablePhotoUrl(AuthUser.fromMeJson(data));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> start(String phone) async {
    final res = await api.dio.post(
      '/telegram/auth/start',
      data: {'phone_number': phone},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> verifyCode(int attemptId, String code) async {
    final res = await api.dio.post(
      '/telegram/auth/verify-code',
      data: {'attempt_id': attemptId, 'code': code},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> verifyPassword(
    int attemptId,
    String password,
  ) async {
    final res = await api.dio.post(
      '/telegram/auth/verify-password',
      data: {'attempt_id': attemptId, 'password': password},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<TdlibCodeResolveResult> resolveTdlibCode({
    required int telegramUserId,
    required String phoneNumber,
    required DateTime startedAt,
    required String nonce,
  }) async {
    final res = await api.dio.post(
      '/telegram/auth/tdlib-code/resolve',
      data: {
        'telegram_user_id': telegramUserId,
        'phone_number': phoneNumber,
        'started_at_ms': startedAt.toUtc().millisecondsSinceEpoch,
        'nonce': nonce,
      },
    );
    return TdlibCodeResolveResult.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<bool?> telegramStatus() async {
    try {
      final res = await api.dio.get('/telegram/auth/status');
      return (res.data as Map)['connected'] as bool?;
    } on DioException catch (err) {
      if (err.response?.statusCode == 401) rethrow;
      return false;
    } catch (_) {
      return null;
    }
  }

  Future<AuthBootstrapResult> bootstrap({
    bool includeDrive = true,
    bool persistUser = true,
    String? tokenOverride,
  }) async {
    final res = await api.dio.get(
      '/frontend/bootstrap',
      options: tokenOverride == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $tokenOverride'}),
      queryParameters: {
        'include_drive': includeDrive,
        'validate_telegram': false,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final user = _withLoadablePhotoUrl(
      AuthUser.fromMeJson(
        Map<String, dynamic>.from(data['currentUser'] as Map),
      ),
      tokenOverride: tokenOverride,
    );
    if (persistUser) await storage.saveUser(user);
    final telegram = data['telegram'] is Map
        ? Map<String, dynamic>.from(data['telegram'] as Map)
        : <String, dynamic>{};
    final uploadLimits = data['uploadLimits'] is Map
        ? Map<String, dynamic>.from(data['uploadLimits'] as Map)
        : null;
    final featureFlags = data['featureFlags'] is Map
        ? Map<String, dynamic>.from(data['featureFlags'] as Map)
        : null;
    final largeThreshold = uploadLimits != null
        ? uploadLimits['largeUploadThresholdBytes'] as int?
        : null;
    final drive = data['drive'] is Map
        ? DriveRepository(
            api,
          ).parseDriveState(Map<String, dynamic>.from(data['drive'] as Map))
        : null;
    return AuthBootstrapResult(
      user: user,
      telegramConnected: telegram['connected'] as bool?,
      communityJoinStatus: telegram['communityJoinStatus'] as String?,
      communityJoinError: telegram['communityJoinError'] as String?,
      communityTargets: _communityTargets(telegram['communityTargets']),
      drive: drive,
      largeUploadThresholdBytes: largeThreshold,
      phoneNumber: telegram['phoneNumber'] as String?,
      telegramUserId: _intish(telegram['telegramUserId']),
      sessionStatus: telegram['status'] as String?,
      requiresReconnect: telegram['requiresReconnect'] == true,
      featureFlags: BackendFeatureFlags.fromJson(featureFlags),
    );
  }

  int? _intish(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<AuthBootstrapResult> bootstrapWithToken(
    String token, {
    bool includeDrive = true,
  }) async {
    return bootstrap(
      includeDrive: includeDrive,
      persistUser: false,
      tokenOverride: token,
    );
  }

  Future<AuthUser> fetchProfile({AuthUser? current}) async {
    final res = await api.dio.get('/me');
    final data = Map<String, dynamic>.from(res.data as Map);
    final parsed = current == null
        ? AuthUser.fromMeJson(data)
        : AuthUser.fromMe(data, current);
    final user = _withLoadablePhotoUrl(parsed);
    await storage.saveUser(user);
    return user;
  }

  /// Refresh one saved identity without changing the shared API token or
  /// persisting it as the active user. The backend checks the current main
  /// Telegram photo ID and downloads bytes only if that ID changed.
  Future<AuthUser> fetchAccountProfile(SavedAccount account) async {
    final res = await api.dio.get(
      '/me',
      queryParameters: {'refresh_telegram': true},
      options: Options(headers: {'Authorization': 'Bearer ${account.token}'}),
    );
    final parsed = AuthUser.fromMeJson(
      Map<String, dynamic>.from(res.data as Map),
    );
    if (parsed.userId != account.userId ||
        (parsed.telegramId != 0 && parsed.telegramId != account.telegramId)) {
      throw const FormatException(
        'Profile response belongs to another account.',
      );
    }
    return _withLoadablePhotoUrl(parsed, tokenOverride: account.token);
  }

  Future<void> saveToken(String token) async {
    api.setToken(token);
    await storage.saveToken(token);
  }

  void setApiToken(String? token) => api.setToken(token);

  Future<void> saveActiveUser(AuthUser user) => storage.saveUser(user);

  Future<String?> cacheProfilePhoto(AuthUser user) async {
    final source = user.photoUrl?.trim();
    if (source == null || source.isEmpty) return null;
    if (_isLocalPath(source)) {
      return source.startsWith('file://')
          ? Uri.parse(source).toFilePath()
          : source;
    }
    try {
      final dir = await this._profilePhotoDir();
      final uri = Uri.tryParse(source);
      final params = Map<String, String>.from(uri?.queryParameters ?? {})
        ..remove('token');
      final identity =
          uri?.replace(queryParameters: params).toString() ?? source;
      final file = File(
        '${dir.path}${Platform.pathSeparator}${user.userId}_${user.telegramId}_${stableHash(identity)}.jpg',
      );
      if (await file.exists()) return file.path;
      final bytes = source.startsWith('data:image')
          ? _decodeDataImage(source)
          : await _downloadProfilePhoto(source);
      if (bytes == null || bytes.isEmpty) return null;
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCachedProfilePhoto(int userId) async {
    try {
      await this._deleteCachedProfilePhotoFiles(userId);
    } catch (_) {}
  }

  Future<void> clearCachedProfilePhotos() async {
    try {
      final dir = await this._profilePhotoDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> logout() async {
    api.setToken(null);
    await storage.clearToken();
  }

  Future<void> clearAllAuthStorage() async {
    api.setToken(null);
    await storage.clearAccountVault();
    await storage.clearToken();
    await clearCachedProfilePhotos();
  }

  Future<void> disconnectTelegram() =>
      api.dio.post('/telegram/auth/disconnect').then((_) {});

  Future<CommunityJoinResult> joinCommunity() async {
    try {
      final res = await api.dio.post('/telegram/auth/join-community');
      return CommunityJoinResult.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } catch (err) {
      return CommunityJoinResult(
        status: 'failed',
        error: api.errorMessage(err),
      );
    }
  }
}
