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

  Future<void> _refreshProfile() async {
    try {
      user = await _repo.fetchProfile(current: user);
      final active = activeAccount;
      if (user != null && active != null) {
        final localPhotoPath =
            await _repo.cacheProfilePhoto(user!) ??
            this._trustedLocalPhotoPath(active);
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
      this._emitChange();
    } catch (_) {}
  }

  Future<void> _disconnectTelegram() async {
    await _repo.disconnectTelegram();
    telegramConnected = false;
    communityJoinStatus = null;
    communityJoinError = null;
    this._emitChange();
  }
}
