import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../models/auth_user.dart';
import '../../models/drive_models.dart';
import 'auth_repository.dart';
import 'models/community_onboarding.dart';

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
  String? communityJoinStatus;
  String? communityJoinError;
  List<CommunityTarget> communityTargets = const [];
  String? error;
  DriveSnapshot? pendingDriveBootstrap;

  bool get isAuthenticated => user != null && token != null;
  bool get needsCommunityOnboarding =>
      isAuthenticated &&
      telegramConnected == true &&
      (communityJoinStatus == null || communityJoinStatus == 'pending');

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      error = null;
      final stored = await _repo.storedToken();
      if (stored == null) return;
      if (_repo.isExpired(stored)) {
        await _repo.logout();
        return;
      }
      token = stored;
      await _repo.saveToken(stored);
      user = await _repo.storedUser() ?? _repo.decode(stored);
      notifyListeners();
      final bootstrap = await _repo.bootstrap(includeDrive: true);
      user = bootstrap.user;
      telegramConnected = bootstrap.telegramConnected;
      communityJoinStatus = bootstrap.communityJoinStatus;
      communityJoinError = bootstrap.communityJoinError;
      communityTargets = bootstrap.communityTargets;
      pendingDriveBootstrap = bootstrap.drive;
    } catch (err) {
      await _repo.logout();
      token = null;
      user = null;
      telegramConnected = null;
      communityJoinStatus = null;
      communityJoinError = null;
      communityTargets = const [];
      pendingDriveBootstrap = null;
      error = _repo.api.errorMessage(err, 'Auth bootstrap failed.');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(
    String nextToken, {
    Map<String, dynamic>? authPayload,
  }) async {
    error = null;
    if (_repo.isExpired(nextToken)) throw Exception('Invalid token received.');
    token = nextToken;
    user =
        (authPayload == null ? null : _repo.userFromAuthPayload(authPayload)) ??
        _repo.decode(nextToken);
    await _repo.saveToken(nextToken);
    final bootstrap = await _repo.bootstrap(includeDrive: true);
    user = bootstrap.user;
    telegramConnected = bootstrap.telegramConnected;
    communityJoinStatus = bootstrap.communityJoinStatus;
    communityJoinError = bootstrap.communityJoinError;
    communityTargets = bootstrap.communityTargets;
    pendingDriveBootstrap = bootstrap.drive;
    notifyListeners();
  }

  Future<void> completeCommunityOnboarding() async {
    final result = await _repo.joinCommunity();
    communityJoinStatus = result.status == 'deferred'
        ? 'failed'
        : result.status;
    communityJoinError = result.error;
    if (result.targets.isNotEmpty) communityTargets = result.targets;
    notifyListeners();
  }

  DriveSnapshot? takePendingDriveBootstrap() {
    final snapshot = pendingDriveBootstrap;
    pendingDriveBootstrap = null;
    return snapshot;
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
    try {
      user = await _repo.fetchProfile(current: user);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repo.logout();
    token = null;
    user = null;
    telegramConnected = null;
    communityJoinStatus = null;
    communityJoinError = null;
    communityTargets = const [];
    pendingDriveBootstrap = null;
    error = null;
    notifyListeners();
  }

  Future<void> disconnectTelegram() async {
    await _repo.disconnectTelegram();
    telegramConnected = false;
    communityJoinStatus = null;
    communityJoinError = null;
    notifyListeners();
  }
}
