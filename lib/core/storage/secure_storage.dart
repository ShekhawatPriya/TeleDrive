import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService();

  static const _tokenKey = 'teledrive_auth_token';
  final _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
