import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/jwt.dart';
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
  });

  final AuthUser user;
  final bool? telegramConnected;
  final String? communityJoinStatus;
  final String? communityJoinError;
  final List<CommunityTarget> communityTargets;
  final DriveSnapshot? drive;
}

class AuthRepository {
  AuthRepository(this.api, this.storage);

  final ApiClient api;
  final SecureStorageService storage;

  Future<String?> storedToken() => storage.readToken();
  Future<AuthUser?> storedUser() => storage.readUser();

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

  Future<AuthBootstrapResult> bootstrap({bool includeDrive = true}) async {
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
    await storage.saveUser(user);
    final telegram = data['telegram'] is Map
        ? Map<String, dynamic>.from(data['telegram'] as Map)
        : <String, dynamic>{};
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

  Future<void> logout() async {
    api.setToken(null);
    await storage.clearToken();
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
}
