part of 'auth_controller.dart';

extension _AuthControllerStatus on AuthController {
  Future<void> _refreshPendingDirectCommitCount() async {
    final activeUser = user;
    if (activeUser == null) {
      pendingDirectCommitCount = 0;
      pendingDirectCommitError = null;
      this._emitChange(); // ignore: unnecessary_this
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
    this._emitChange();
  }

  Future<void> _completeCommunityOnboarding() async {
    final result = await _repo.joinCommunity();
    communityJoinStatus = result.status == 'deferred'
        ? 'failed'
        : result.status;
    communityJoinError = result.error;
    if (result.targets.isNotEmpty) communityTargets = result.targets;
    this._emitChange();
  }

  DriveSnapshot? _takePendingDriveBootstrap() {
    final snapshot = pendingDriveBootstrap;
    pendingDriveBootstrap = null;
    return snapshot;
  }

  Future<void> _refreshTelegramStatus() async {
    if (token == null) {
      telegramConnected = null;
      this._emitChange();
      return;
    }
    telegramConnected = await _repo.telegramStatus();
    this._emitChange();
  }

  Future<void> _refreshProfile() {
    final pending = _profileRefresh;
    if (pending != null) return pending;
    final future = _refreshActiveProfile();
    _profileRefresh = future;
    return future.whenComplete(() {
      if (identical(_profileRefresh, future)) _profileRefresh = null;
    });
  }

  Future<void> _refreshActiveProfile() async {
    final account = activeAccount;
    final epoch = _sessionEpoch;
    if (account == null || !isAuthenticated || switchingAccount) return;
    try {
      final profile = await _repo.fetchAccountProfile(account);
      if (!_profileRequestIsCurrent(account, epoch) || token != account.token)
        return;
      final local = await _profileLocalPhoto(account, profile);
      if (!_profileRequestIsCurrent(account, epoch) || token != account.token)
        return;
      user = profile;
      final latest = vault.accountByUserId(account.userId)!;
      vault = vault.upsert(_updatedProfile(latest, profile, local));
      await _repo.saveActiveUser(profile);
      if (!_profileRequestIsCurrent(account, epoch)) return;
      await _repo.saveVault(vault);
      _emitChange();
    } catch (_) {
      /* Keep the last good identity on a transient failure. */
    }
  }

  bool _profileRequestIsCurrent(SavedAccount account, int epoch) {
    final current = vault.accountByUserId(account.userId);
    return !_disposed &&
        epoch == _sessionEpoch &&
        current != null &&
        current.token == account.token &&
        current.addedAt == account.addedAt &&
        current.telegramId == account.telegramId;
  }

  Future<String?> _profileLocalPhoto(SavedAccount account, AuthUser profile) {
    if (profile.photoUrl == null) return Future.value(null);
    if (profile.photoUrl == account.photoUrl &&
        account.localPhotoPath != null) {
      return Future.value(account.localPhotoPath);
    }
    return _repo.cacheProfilePhoto(profile);
  }

  SavedAccount _updatedProfile(
    SavedAccount account,
    AuthUser profile,
    String? local,
  ) => account.copyWith(
    firstName: profile.firstName,
    lastName: profile.lastName,
    clearLastName: profile.lastName == null,
    username: profile.username,
    clearUsername: profile.username == null,
    photoUrl: profile.photoUrl,
    clearPhotoUrl: profile.photoUrl == null,
    localPhotoPath: local,
    clearLocalPhotoPath: local == null,
  );

  Future<void> _disconnectTelegram() async {
    await _repo.disconnectTelegram();
    telegramConnected = false;
    communityJoinStatus = null;
    communityJoinError = null;
    this._emitChange();
  }
}
