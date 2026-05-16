import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/jwt.dart';
import '../../models/auth_user.dart';

class AuthRepository {
  AuthRepository(this.api, this.storage);

  final ApiClient api;
  final SecureStorageService storage;

  Future<String?> storedToken() => storage.readToken();

  AuthUser? decode(String token) => decodeJwtUser(token);

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

  Future<AuthUser?> fetchProfile(AuthUser current) async {
    final res = await api.dio.get('/me');
    return AuthUser.fromMe(Map<String, dynamic>.from(res.data as Map), current);
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
}
