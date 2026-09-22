part of 'auth_controller.dart';

extension _AuthControllerStatus on AuthController {
  Future<void> _refreshPendingDirectCommitCount() async {
    final generation = _authGeneration;
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
    final count = await _pendingCommits.pendingCount(
      backendUserId: activeUser.userId,
      telegramUserId: telegramId,
    );
    if (generation != _authGeneration) return;
    pendingDirectCommitCount = count;
    if (pendingDirectCommitCount == 0) pendingDirectCommitError = null;
    this._emitChange();
  }

  Future<void> _completeCommunityOnboarding() async {
    final generation = _authGeneration;
    final result = await _repo.joinCommunity();
    if (generation != _authGeneration) return;
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
    final generation = _authGeneration;
    if (token == null) {
      telegramConnected = null;
      this._emitChange();
      return;
    }
    final connected = await _repo.telegramStatus();
    if (generation != _authGeneration) return;
    telegramConnected = connected;
    this._emitChange();
  }

  Future<void> _refreshProfile() async {
    final generation = _authGeneration;
    final current = user;
    if (current == null || token == null || switchingAccount) return;
    try {
      final refreshed = await _repo.fetchProfile(current: current);
      if (generation != _authGeneration || refreshed.userId != current.userId) {
        return;
      }
      final active = activeAccount;
      if (active != null) {
        final localPhotoPath =
            await _repo.cacheProfilePhoto(refreshed) ??
            this._trustedLocalPhotoPath(active);
        if (!_isCurrentAccount(generation, active)) return;
        final updated = active.copyWith(
          firstName: refreshed.firstName,
          lastName: refreshed.lastName,
          username: refreshed.username,
          photoUrl: refreshed.photoUrl,
          localPhotoPath: localPhotoPath,
        );
        vault = vault.upsert(updated, makeActive: true);
        await _saveVault();
      }
      if (generation != _authGeneration) return;
      user = refreshed;
      await _persistAuth(() => _repo.saveActiveUser(refreshed));
      if (generation != _authGeneration) return;
      this._emitChange();
    } catch (_) {}
  }

  Future<void> _disconnectTelegram() async {
    final generation = _authGeneration;
    await _repo.disconnectTelegram();
    if (generation != _authGeneration) return;
    telegramConnected = false;
    communityJoinStatus = null;
    communityJoinError = null;
    this._emitChange();
  }
}
