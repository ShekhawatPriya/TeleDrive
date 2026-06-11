part of 'auth_controller.dart';

extension _AuthControllerAccounts on AuthController {
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
        if (err.response == null) {
          // Backend unreachable right now (network change, tunnel down,
          // server still booting). The token is locally valid, so restore the
          // session from the vault instead of dumping the user to the welcome
          // screen; data loads recover as soon as requests succeed.
          _repo.setApiToken(account.token);
          token = account.token;
          user = account.toAuthUser();
          vault = vault.upsert(account, makeActive: true);
          return;
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
          _emitChange();
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
        _emitChange();
      } on DioException catch (err) {
        if (err.response?.statusCode == 401) {
          vault = vault.markTokenStatus(account.userId, TokenStatus.needsLogin);
          await _repo.saveVault(vault);
          _emitChange();
        }
      } catch (_) {}
    }
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
        _emitChange();
        return;
      }
      debugPrint('TDLIB_E2E_PENDING_COMMIT_RETRY before=$before');
      pendingDirectCommitCount = before;
      pendingDirectCommitError = null;
      _emitChange();
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
      _emitChange();
    } catch (err) {
      pendingDirectCommitError = _repo.api.errorMessage(
        err,
        'Pending Telegram commit retry failed.',
      );
      _emitChange();
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
      phoneNumber:
          bootstrap.phoneNumber ??
          existing?.phoneNumber ??
          pendingCandidatePhone,
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

  void _clearSessionState({bool clearVault = true}) {
    clearEphemeralTelegramCloudPassword();
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
