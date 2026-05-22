import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/jwt.dart';
import '../../models/account_vault.dart';
import '../../models/auth_user.dart';
import '../../models/drive_models.dart';
import '../drive/drive_repository.dart';
import 'models/community_onboarding.dart';

class AuthBootstrapResult {
  const AuthBootstrapResult({
    required this.user,
    required this.telegramConnected,
    this.communityJoinStatus,
    this.communityJoinError,
    this.communityTargets = const [],
    this.drive,
    this.largeUploadThresholdBytes,
    this.phoneNumber,
    this.telegramUserId,
    this.sessionStatus,
    this.requiresReconnect = false,
  });

  final AuthUser user;
  final bool? telegramConnected;
  final String? communityJoinStatus;
  final String? communityJoinError;
  final List<CommunityTarget> communityTargets;
  final DriveSnapshot? drive;
  final int? largeUploadThresholdBytes;
  final String? phoneNumber;
  final int? telegramUserId;
  final String? sessionStatus;
  final bool requiresReconnect;
}

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
  }) async {
    final res = await api.dio.get(
      '/frontend/bootstrap',
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
    );
    if (persistUser) await storage.saveUser(user);
    final telegram = data['telegram'] is Map
        ? Map<String, dynamic>.from(data['telegram'] as Map)
        : <String, dynamic>{};
    final uploadLimits = data['uploadLimits'] is Map
        ? Map<String, dynamic>.from(data['uploadLimits'] as Map)
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
      telegramUserId: (telegram['telegramUserId'] as num?)?.toInt(),
      sessionStatus: telegram['status'] as String?,
      requiresReconnect: telegram['requiresReconnect'] == true,
    );
  }

  Future<AuthBootstrapResult> bootstrapWithToken(
    String token, {
    bool includeDrive = true,
  }) async {
    final previous = api.token;
    api.setToken(token);
    try {
      return await bootstrap(includeDrive: includeDrive, persistUser: false);
    } finally {
      api.setToken(previous);
    }
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

  AuthUser _withLoadablePhotoUrl(AuthUser user) {
    final photoUrl = user.photoUrl?.trim();
    if (photoUrl == null || photoUrl.isEmpty || photoUrl.startsWith('data:')) {
      return user;
    }
    final uri = Uri.tryParse(photoUrl);
    if (uri != null && uri.hasScheme) return user;
    return user.copyWith(photoUrl: api.mediaUrl(photoUrl));
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
      final bytes = source.startsWith('data:image')
          ? _decodeDataImage(source)
          : await _downloadProfilePhoto(source);
      if (bytes == null || bytes.isEmpty) return null;
      final dir = await _profilePhotoDir();
      await _deleteCachedProfilePhotoFiles(user.userId);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${dir.path}${Platform.pathSeparator}${user.userId}_${user.telegramId}_$stamp.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCachedProfilePhoto(int userId) async {
    try {
      await _deleteCachedProfilePhotoFiles(userId);
    } catch (_) {}
  }

  Future<void> clearCachedProfilePhotos() async {
    try {
      final dir = await _profilePhotoDir();
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

  List<CommunityTarget> _communityTargets(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => CommunityTarget.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Directory> _profilePhotoDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}teledrive${Platform.pathSeparator}profile_photos',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<int>? _decodeDataImage(String source) {
    final comma = source.indexOf(',');
    if (comma == -1) return null;
    return base64Decode(source.substring(comma + 1));
  }

  Future<List<int>?> _downloadProfilePhoto(String source) async {
    final response = await Dio().get<List<int>>(
      source,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }

  Future<void> _deleteCachedProfilePhotoFiles(int userId) async {
    final dir = await _profilePhotoDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last;
      if (name == '$userId.jpg' || name.startsWith('${userId}_')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  bool _isLocalPath(String value) {
    if (value.startsWith('file://')) return true;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.isNotEmpty) return false;
    return value.startsWith('/') || RegExp(r'^[A-Za-z]:\\').hasMatch(value);
  }
}
