import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/telegram/pending_telegram_commit_queue.dart';
import '../../core/utils/iterable_ext.dart';
import '../../models/account_vault.dart';
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
  bool get legacyBackendUploadFallbackEnabled =>
      AppConfig.legacyBackendUploadFallbackEnabled &&
      featureFlags.legacyBackendUploadFallbackEnabled;
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

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      error = null;
      vault = await _loadVaultWithLegacyMigration();
      if (vault.accounts.isEmpty) {
        _repo.setApiToken(null);
        _clearSessionState(clearVault: false);
        return;
      }
      await _restoreBestAccount();
      unawaited(_refreshSavedAccountSnapshots());
    } catch (err) {
      _repo.setApiToken(null);
      _clearSessionState(clearVault: false);
      error = _repo.api.errorMessage(err, 'Auth bootstrap failed.');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<AccountVault> _loadVaultWithLegacyMigration() async {
    var loaded = await _repo.storedVault();
    loaded = _markLocallyExpired(loaded);
    if (loaded.accounts.isNotEmpty) return loaded;

    final legacyToken = await _repo.storedToken();
    if (legacyToken == null || legacyToken.isEmpty) return loaded;
    if (_repo.isExpired(legacyToken)) return loaded;

    final bootstrap = await _repo.bootstrapWithToken(
      legacyToken,
      includeDrive: true,
    );
    final migrated = _accountFromBootstrap(legacyToken, bootstrap);
    loaded = const AccountVault.empty().upsert(migrated, makeActive: true);
    await _repo.saveVault(loaded);
    return loaded;
  }

  AccountVault _markLocallyExpired(AccountVault current) {
    var updated = current;
    for (final account in current.accounts) {
      if (_repo.isExpired(account.token) &&
          account.tokenStatus != TokenStatus.expired) {
        updated = updated.markTokenStatus(account.userId, TokenStatus.expired);
      }
    }
    if (!_sameVault(updated, current)) {
      _repo.saveVault(updated);
    }
    return updated;
  }

  bool _sameVault(AccountVault a, AccountVault b) {
    if (a.activeUserId != b.activeUserId ||
        a.accounts.length != b.accounts.length) {
      return false;
    }
    for (var i = 0; i < a.accounts.length; i++) {
      if (a.accounts[i].tokenStatus != b.accounts[i].tokenStatus) return false;
    }
    return true;
  }

  Future<void> _restoreBestAccount() async {
    final active = vault.activeAccount;
    final candidates = <SavedAccount>[
      if (active != null) active,
      ...vault.validAccountsByRecent().where((a) => a.userId != active?.userId),
    ];

    for (final account in candidates) {
      if (account.tokenStatus != TokenStatus.valid) {
        continue;
      }
      if (_repo.isExpired(account.token)) {
        vault = vault.markTokenStatus(account.userId, TokenStatus.expired);
        await _repo.saveVault(vault);
        continue;
      }
      try {
        final bootstrap = await _repo.bootstrapWithToken(
          account.token,
          includeDrive: true,
        );
        if (!_bootstrapMatchesAccount(account, bootstrap)) {
          vault = vault.markTokenStatus(account.userId, TokenStatus.needsLogin);
          await _repo.saveVault(vault);
          continue;
        }
        await _commitActiveAccount(account.token, bootstrap, existing: account);
        return;
      } on DioException catch (err) {
        if (err.response?.statusCode == 401) {
          vault = vault.markTokenStatus(account.userId, TokenStatus.needsLogin);
          await _repo.saveVault(vault);
          continue;
        }
        rethrow;
      }
    }

    _repo.setApiToken(null);
    _clearSessionState(clearVault: false);
  }

  Future<void> _refreshSavedAccountSnapshots() async {
    for (final account in [...vault.accounts]) {
      if (account.userId == activeAccount?.userId) continue;
      if (account.tokenStatus != TokenStatus.valid ||
          _repo.isExpired(account.token)) {
        continue;
      }
      try {
        final bootstrap = await _repo.bootstrapWithToken(
          account.token,
          includeDrive: false,
        );
        if (!_bootstrapMatchesAccount(account, bootstrap)) {
          vault = vault.markTokenStatus(account.userId, TokenStatus.needsLogin);
          await _repo.saveVault(vault);
          notifyListeners();
          continue;
        }
        final localPhotoPath =
            await _repo.cacheProfilePhoto(bootstrap.user) ??
            _trustedLocalPhotoPath(account);
        final updated = _accountFromBootstrap(
          account.token,
          bootstrap,
          existing: account,
          localPhotoPath: localPhotoPath,
        );
        vault = vault.upsert(updated, makeActive: false);
        await _repo.saveVault(vault);
        notifyListeners();
      } on DioException catch (err) {
        if (err.response?.statusCode == 401) {
          vault = vault.markTokenStatus(account.userId, TokenStatus.needsLogin);
          await _repo.saveVault(vault);
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<void> login(
    String nextToken, {
    Map<String, dynamic>? authPayload,
  }) async {
    error = null;
    if (_repo.isExpired(nextToken)) throw Exception('Invalid token received.');
    final bootstrap = await _repo.bootstrapWithToken(
      nextToken,
      includeDrive: true,
    );
    await _commitActiveAccount(nextToken, bootstrap);
    notifyListeners();
  }

  Future<void> switchToAccount(int userId) async {
    final selected = vault.accounts
        .where((account) => account.userId == userId)
        .firstOrNull;
    if (selected == null || selected.userId == activeAccount?.userId) return;
    if (selected.tokenStatus != TokenStatus.valid ||
        _repo.isExpired(selected.token)) {
      vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
      await _repo.saveVault(vault);
      notifyListeners();
      throw Exception('Session expired. Please log in again.');
    }

    switchingAccount = true;
    notifyListeners();
    try {
      final bootstrap = await _repo.bootstrapWithToken(
        selected.token,
        includeDrive: true,
      );
      if (!_bootstrapMatchesAccount(selected, bootstrap)) {
        vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
        await _repo.saveVault(vault);
        throw Exception('Session expired. Please log in again.');
      }
      await _commitActiveAccount(selected.token, bootstrap, existing: selected);
    } on DioException catch (err) {
      if (err.response?.statusCode == 401) {
        vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
        await _repo.saveVault(vault);
        throw Exception('Session expired. Please log in again.');
      }
      rethrow;
    } finally {
      switchingAccount = false;
      notifyListeners();
    }
  }

  Future<bool> removeAccountFromDevice(int userId) async {
    final wasActive = activeAccount?.userId == userId;
    vault = vault.remove(userId);
    await _repo.saveVault(vault);
    await _repo.deleteCachedProfilePhoto(userId);
    if (!wasActive) {
      notifyListeners();
      return isAuthenticated;
    }

    final candidates = vault.validAccountsByRecent();
    for (final candidate in candidates) {
      try {
        await switchToAccount(candidate.userId);
        return true;
      } catch (_) {
        vault = vault.markTokenStatus(candidate.userId, TokenStatus.needsLogin);
        await _repo.saveVault(vault);
      }
    }
    await signOutAll();
    return false;
  }

  Future<void> signOutAll() async {
    await _repo.clearAllAuthStorage();
    _clearSessionState();
    notifyListeners();
  }

  Future<void> markAccountNeedsLogin(int userId) async {
    vault = vault.markTokenStatus(userId, TokenStatus.needsLogin);
    await _repo.saveVault(vault);
    notifyListeners();
  }

  Future<void> refreshSavedAccountSnapshots() =>
      _refreshSavedAccountSnapshots();

  Future<void> refreshPendingDirectCommitCount() async {
    final activeUser = user;
    if (activeUser == null) {
      pendingDirectCommitCount = 0;
      pendingDirectCommitError = null;
      notifyListeners();
      return;
    }
    final telegramId = activeUser.telegramId != 0
        ? activeUser.telegramId
        : activeAccount?.telegramId ?? 0;
    if (telegramId == 0) return;
    pendingDirectCommitCount = await _pendingCommits.pendingCount(
      backendUserId: activeUser.userId,
      telegramUserId: telegramId,
    );
    if (pendingDirectCommitCount == 0) pendingDirectCommitError = null;
    notifyListeners();
  }

  Future<void> _commitActiveAccount(
    String nextToken,
    AuthBootstrapResult bootstrap, {
    SavedAccount? existing,
  }) async {
    final localPhotoPath =
        await _repo.cacheProfilePhoto(bootstrap.user) ??
        _trustedLocalPhotoPath(existing);
    final account = _accountFromBootstrap(
      nextToken,
      bootstrap,
      existing: existing,
      localPhotoPath: localPhotoPath,
    );
    vault = vault
        .upsert(account, makeActive: true)
        .touchActive(account.userId, DateTime.now());
    await _repo.saveVault(vault);
    _repo.setApiToken(nextToken);
    token = nextToken;
    user = bootstrap.user;
    await _repo.saveActiveUser(bootstrap.user);
    telegramConnected = bootstrap.telegramConnected;
    communityJoinStatus = bootstrap.communityJoinStatus;
    communityJoinError = bootstrap.communityJoinError;
    communityTargets = bootstrap.communityTargets;
    pendingDriveBootstrap = bootstrap.drive;
    if (bootstrap.largeUploadThresholdBytes != null) {
      largeUploadThresholdBytes = bootstrap.largeUploadThresholdBytes!;
    }
    featureFlags = bootstrap.featureFlags;
    unawaited(_retryPendingDirectCommitsForActiveAccount());
  }

  Future<void> _retryPendingDirectCommitsForActiveAccount() async {
    final activeUser = user;
    if (activeUser == null) return;
    final telegramId = activeUser.telegramId != 0
        ? activeUser.telegramId
        : activeAccount?.telegramId ?? 0;
    if (telegramId == 0) return;
    try {
      final before = await _pendingCommits.pendingCount(
        backendUserId: activeUser.userId,
        telegramUserId: telegramId,
      );
      if (before == 0) {
        pendingDirectCommitCount = 0;
        pendingDirectCommitError = null;
        notifyListeners();
        return;
      }
      debugPrint('TDLIB_E2E_PENDING_COMMIT_RETRY before=$before');
      pendingDirectCommitCount = before;
      pendingDirectCommitError = null;
      notifyListeners();
      final result = await _pendingCommits.retryPending(
        api: _repo.api,
        backendUserId: activeUser.userId,
        telegramUserId: telegramId,
      );
      debugPrint(
        'TDLIB_E2E_PENDING_COMMIT_RETRY_RESULT '
        'attempted=${result.attempted} committed=${result.committed} '
        'failed=${result.failed}',
      );
      pendingDirectCommitCount = await _pendingCommits.pendingCount(
        backendUserId: activeUser.userId,
        telegramUserId: telegramId,
      );
      pendingDirectCommitError = result.lastError;
      if (result.committed > 0) {
        try {
          final refreshed = await _repo.bootstrap(includeDrive: true);
          pendingDriveBootstrap = refreshed.drive;
        } catch (_) {}
      }
      notifyListeners();
    } catch (err) {
      pendingDirectCommitError = _repo.api.errorMessage(
        err,
        'Pending Telegram commit retry failed.',
      );
      notifyListeners();
    }
  }

  SavedAccount _accountFromBootstrap(
    String nextToken,
    AuthBootstrapResult bootstrap, {
    SavedAccount? existing,
    String? localPhotoPath,
  }) {
    final now = DateTime.now();
    final telegramId = bootstrap.user.telegramId != 0
        ? bootstrap.user.telegramId
        : (bootstrap.telegramUserId ?? existing?.telegramId ?? 0);
    return SavedAccount(
      userId: bootstrap.user.userId,
      telegramId: telegramId,
      firstName: bootstrap.user.firstName,
      lastName: bootstrap.user.lastName,
      username: bootstrap.user.username,
      phoneNumber: bootstrap.phoneNumber ?? existing?.phoneNumber,
      photoUrl: bootstrap.user.photoUrl,
      localPhotoPath: localPhotoPath,
      token: nextToken,
      addedAt: existing?.addedAt ?? now,
      lastUsedAt: now,
      tokenStatus: TokenStatus.valid,
      sessionStatus: bootstrap.sessionStatus,
      requiresReconnect: bootstrap.requiresReconnect,
    );
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
      final active = activeAccount;
      if (user != null && active != null) {
        final localPhotoPath =
            await _repo.cacheProfilePhoto(user!) ??
            _trustedLocalPhotoPath(active);
        final updated = active.copyWith(
          firstName: user!.firstName,
          lastName: user!.lastName,
          username: user!.username,
          photoUrl: user!.photoUrl,
          localPhotoPath: localPhotoPath,
        );
        vault = vault.upsert(updated, makeActive: true);
        await _repo.saveVault(vault);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await signOutAll();
  }

  void _clearSessionState({bool clearVault = true}) {
    token = null;
    user = null;
    telegramConnected = null;
    communityJoinStatus = null;
    communityJoinError = null;
    communityTargets = const [];
    pendingDriveBootstrap = null;
    error = null;
    featureFlags = const BackendFeatureFlags();
    pendingDirectCommitCount = 0;
    pendingDirectCommitError = null;
    if (clearVault) vault = const AccountVault.empty();
  }

  Future<void> disconnectTelegram() async {
    await _repo.disconnectTelegram();
    telegramConnected = false;
    communityJoinStatus = null;
    communityJoinError = null;
    notifyListeners();
  }

  bool _bootstrapMatchesAccount(
    SavedAccount account,
    AuthBootstrapResult bootstrap,
  ) {
    if (bootstrap.user.userId == account.userId) return true;
    final telegramId = _bootstrapTelegramId(bootstrap);
    return account.telegramId != 0 &&
        telegramId != 0 &&
        account.telegramId == telegramId;
  }

  int _bootstrapTelegramId(AuthBootstrapResult bootstrap) {
    if (bootstrap.user.telegramId != 0) return bootstrap.user.telegramId;
    return bootstrap.telegramUserId ?? 0;
  }

  String? _trustedLocalPhotoPath(SavedAccount? account) {
    if (account == null) return null;
    return account.localPhotoPath == account.resolvedPhotoUrl
        ? account.localPhotoPath
        : null;
  }
}
