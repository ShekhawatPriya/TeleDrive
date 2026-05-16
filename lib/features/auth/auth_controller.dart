import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../models/auth_user.dart';
import 'auth_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider))..bootstrap();
});

class AuthController extends ChangeNotifier {
  AuthController(this._repo);

  final AuthRepository _repo;
  AuthUser? user;
  String? token;
  bool loading = true;
  bool? telegramConnected;
  String? error;

  bool get isAuthenticated => user != null && token != null;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      final stored = await _repo.storedToken();
      if (stored == null) return;
      final decoded = _repo.decode(stored);
      if (decoded == null) {
        await _repo.logout();
        return;
      }
      token = stored;
      user = decoded;
      await _repo.saveToken(stored);
      await refreshTelegramStatus();
      await refreshProfile();
    } catch (err) {
      error = _repo.api.errorMessage(err, 'Auth bootstrap failed.');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String nextToken) async {
    final decoded = _repo.decode(nextToken);
    if (decoded == null) throw Exception('Invalid token received.');
    token = nextToken;
    user = decoded;
    await _repo.saveToken(nextToken);
    await refreshTelegramStatus();
    await refreshProfile();
    notifyListeners();
  }

  Future<void> refreshTelegramStatus() async {
    if (token == null) {
      telegramConnected = null;
      notifyListeners();
      return;
    }
    telegramConnected = await _repo.telegramStatus();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final current = user;
    if (current == null) return;
    try {
      user = await _repo.fetchProfile(current) ?? current;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repo.logout();
    token = null;
    user = null;
    telegramConnected = null;
    notifyListeners();
  }

  Future<void> disconnectTelegram() async {
    await _repo.disconnectTelegram();
    telegramConnected = false;
    notifyListeners();
  }
}
