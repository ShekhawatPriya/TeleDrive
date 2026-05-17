import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auth_user.dart';

class SecureStorageService {
  SecureStorageService();

  static const _tokenKey = 'teledrive_auth_token';
  static const _userKey = 'teledrive_auth_user';
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

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
