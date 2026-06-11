import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/network/api_client.dart';
import '../../core/network/backend_resolver.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/telegram/pending_telegram_commit_queue.dart';
import '../../core/utils/iterable_ext.dart';
import '../../models/account_vault.dart';
import '../../models/auth_user.dart';
import '../../models/drive_models.dart';
import 'auth_repository.dart';
import 'models/community_onboarding.dart';

part 'auth_controller_accounts.dart';
part 'auth_controller_status.dart';
part 'auth_controller_session_actions.dart';
part 'auth_controller_pending.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(backendResolverProvider)),
);
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
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(secureStorageProvider),
  )..bootstrap();
});

enum PendingTdlibMode { normalLogin, addAccount, reauthenticateAccount }

class AuthController extends ChangeNotifier {
  AuthController(this._repo, this._storage);

  final AuthRepository _repo;
  final SecureStorageService _storage;
  final PendingTelegramCommitQueue _pendingCommits =
      PendingTelegramCommitQueue();
  AuthUser? user;
  String? token;
  bool loading = true;
  bool switchingAccount = false;
  bool? telegramConnected;
  BackendFeatureFlags featureFlags = const BackendFeatureFlags();
  String? communityJoinStatus;
  String? communityJoinError;
  List<CommunityTarget> communityTargets = const [];
  AccountVault vault = const AccountVault.empty();
  String? error;
  final Map<int, String> _ephemeralCloudPasswords = {};
  PendingTdlibMode? pendingTdlibMode;
  int? pendingPreviousUserId;
  int? pendingCandidateUserId;
  int? pendingCandidateTelegramId;
  String? pendingCandidatePhone;
  String? pendingReturnTo;
  DriveSnapshot? pendingDriveBootstrap;
  int largeUploadThresholdBytes = 200 * 1024 * 1024;
  int pendingDirectCommitCount = 0;
  String? pendingDirectCommitError;

  bool get isAuthenticated => user != null && token != null;
  bool get directTelegramUploadEnabled =>
      AppConfig.directTelegramUploadEnabled &&
      featureFlags.directTelegramUploadEnabled;
  bool get directTelegramDownloadEnabled =>
      AppConfig.directTelegramDownloadEnabled &&
      featureFlags.directTelegramDownloadEnabled;
  bool get clientDerivativeGenerationEnabled =>
      AppConfig.clientDerivativeGenerationEnabled &&
      featureFlags.clientDerivativeGenerationEnabled;
  bool get galleryBackupEnabled =>
      AppConfig.galleryBackupEnabled && featureFlags.galleryBackupEnabled;
  bool get hasPendingDirectCommits => pendingDirectCommitCount > 0;
  SavedAccount? get activeAccount {
    final activeUser = user;
    if (activeUser != null) {
      return vault.accountByUserId(activeUser.userId) ?? vault.activeAccount;
    }
    return vault.activeAccount;
  }

  bool get needsCommunityOnboarding =>
      isAuthenticated &&
      telegramConnected == true &&
      (communityJoinStatus == null || communityJoinStatus == 'pending');

  Future<void> bootstrap() => _bootstrap();

  Future<void> login(String nextToken, {Map<String, dynamic>? authPayload}) =>
      _login(nextToken, authPayload: authPayload);

  void rememberEphemeralTelegramCloudPassword(
    int telegramUserId,
    String value,
  ) => _rememberEphemeralTelegramCloudPassword(telegramUserId, value);

  String? takeEphemeralTelegramCloudPassword(int telegramUserId) =>
      _takeEphemeralTelegramCloudPassword(telegramUserId);

  void clearEphemeralTelegramCloudPassword({int? telegramUserId}) =>
      _clearEphemeralTelegramCloudPassword(telegramUserId: telegramUserId);

  void beginPendingAccountAuthorization({
    required PendingTdlibMode mode,
    required int candidateUserId,
    required int candidateTelegramId,
    required String candidatePhone,
    String? returnTo,
  }) => _beginPendingAccountAuthorization(
    mode: mode,
    candidateUserId: candidateUserId,
    candidateTelegramId: candidateTelegramId,
    candidatePhone: candidatePhone,
    returnTo: returnTo,
  );

  void updatePendingAccountCandidate({
    required int candidateUserId,
    required int candidateTelegramId,
  }) => _updatePendingAccountCandidate(
    candidateUserId: candidateUserId,
    candidateTelegramId: candidateTelegramId,
  );

  String commitPendingAccountAuthorization() =>
      _commitPendingAccountAuthorization();

  Future<String> abortPendingTdlibAuthorization() =>
      _abortPendingTdlibAuthorization();

  Future<void> switchToAccount(int userId) => _switchToAccount(userId);

  Future<bool> removeAccountFromDevice(int userId) =>
      _removeAccountFromDevice(userId);

  Future<void> signOutAll() => _signOutAll();

  Future<void> markAccountNeedsLogin(int userId) =>
      _markAccountNeedsLogin(userId);

  Future<void> refreshSavedAccountSnapshots() =>
      _refreshSavedAccountSnapshots();

  Future<void> refreshPendingDirectCommitCount() =>
      _refreshPendingDirectCommitCount();

  Future<void> completeCommunityOnboarding() => _completeCommunityOnboarding();

  DriveSnapshot? takePendingDriveBootstrap() => _takePendingDriveBootstrap();

  Future<void> refreshTelegramStatus() => _refreshTelegramStatus();

  Future<void> refreshProfile() => _refreshProfile();

  Future<void> logout() => _logout();

  Future<void> disconnectTelegram() => _disconnectTelegram();

  void _emitChange() {
    notifyListeners();
  }
}
