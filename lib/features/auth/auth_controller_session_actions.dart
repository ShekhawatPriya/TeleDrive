part of 'auth_controller.dart';

extension _AuthControllerSessionActions on AuthController {
  Future<void> _bootstrap() async {
    final generation = ++_authGeneration;
    loading = true;
    this._emitChange(); // ignore: unnecessary_this
    try {
      error = null;
      final loaded = await _loadVaultWithLegacyMigration(generation);
      _requireGeneration(generation);
      vault = loaded;
      if (vault.accounts.isEmpty) {
        _repo.setApiToken(null);
        this._clearSessionState(clearVault: false); // ignore: unnecessary_this
        return;
      }
      await _restoreBestAccount(generation);
      _requireGeneration(generation);
      unawaited(
        this._refreshSavedAccountSnapshots(),
      ); // ignore: unnecessary_this
    } catch (err) {
      if (generation != _authGeneration) return;
      _repo.setApiToken(null);
      this._clearSessionState(clearVault: false);
      error = _repo.api.errorMessage(err, 'Auth bootstrap failed.');
    } finally {
      if (generation == _authGeneration) {
        loading = false;
        this._emitChange();
      }
    }
  }

  Future<void> _login(
    String nextToken, {
    Map<String, dynamic>? authPayload,
  }) async {
    final generation = ++_authGeneration;
    switchingAccount = false;
    error = null;
    if (_repo.isExpired(nextToken)) throw Exception('Invalid token received.');
    final bootstrap = await _repo.bootstrapWithToken(
      nextToken,
      includeDrive: true,
    );
    _requireGeneration(generation);
    await this._commitActiveAccount(
      nextToken,
      bootstrap,
      generation: generation,
    ); // ignore: unnecessary_this
    this._emitChange(); // ignore: unnecessary_this
  }

  Future<void> _switchToAccount(int userId) async {
    final selected = vault.accounts
        .where((account) => account.userId == userId)
        .firstOrNull;
    if (selected == null || selected.userId == activeAccount?.userId) return;
    final generation = ++_authGeneration;
    if (selected.tokenStatus != TokenStatus.valid ||
        _repo.isExpired(selected.token)) {
      vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
      await _saveVault();
      _emitChange();
      throw Exception('Session expired. Please log in again.');
    }

    _invalidateProfileRefreshes();
    switchingAccount = true;
    _emitChange();
    try {
      final bootstrap = await _repo.bootstrapWithToken(
        selected.token,
        includeDrive: true,
      );
      _requireGeneration(generation);
      if (!this._bootstrapMatchesAccount(selected, bootstrap)) {
        // ignore: unnecessary_this
        vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
        await _saveVault();
        throw Exception('Session expired. Please log in again.');
      }
      await this._commitActiveAccount(
        selected.token,
        bootstrap,
        existing: selected,
        generation: generation,
      );
    } on DioException catch (err) {
      _requireGeneration(generation);
      if (err.response?.statusCode == 401) {
        vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
        await _saveVault();
        throw Exception('Session expired. Please log in again.');
      }
      rethrow;
    } finally {
      if (generation == _authGeneration) {
        switchingAccount = false;
        this._emitChange();
      }
    }
  }

  Future<bool> _removeAccountFromDevice(int userId) async {
    var generation = ++_authGeneration;
    switchingAccount = false;
    final wasActive = activeAccount?.userId == userId;
    final removed = vault.accountByUserId(userId);
    vault = vault.remove(userId);
    await _saveVault();
    if (generation != _authGeneration) return isAuthenticated;
    await _repo.deleteCachedProfilePhoto(userId);
    if (generation != _authGeneration) return isAuthenticated;
    if (removed != null && removed.telegramId != 0) {
      try {
        await _storage.deleteTelegramCloudPassword(
          backendUserId: removed.userId,
          telegramUserId: removed.telegramId,
        );
      } catch (_) {}
    }
    if (generation != _authGeneration) return isAuthenticated;
    clearEphemeralTelegramCloudPassword(telegramUserId: removed?.telegramId);
    if (!wasActive) {
      this._emitChange();
      return isAuthenticated;
    }

    final candidates = vault.validAccountsByRecent();
    for (final candidate in candidates) {
      if (generation != _authGeneration) return isAuthenticated;
      final switchingGeneration = generation + 1;
      try {
        await switchToAccount(candidate.userId);
        return isAuthenticated;
      } catch (_) {
        if (_authGeneration != switchingGeneration) return isAuthenticated;
        generation = switchingGeneration;
        vault = vault.markTokenStatus(candidate.userId, TokenStatus.needsLogin);
        await _saveVault();
      }
    }
    if (generation != _authGeneration) return isAuthenticated;
    await signOutAll();
    return isAuthenticated;
  }

  Future<void> _signOutAll() async {
    ++_authGeneration;
    final previousActive = activeAccount;
    switchingAccount = false;
    loading = false;
    _repo.setApiToken(null);
    _clearPendingAccountAuthorization();
    _clearSessionState();
    _emitChange();
    await _persistAuth(_repo.clearAllAuthStorage);
    if (previousActive != null) {
      try {
        await _storage.deleteAllTelegramCloudPasswordsForUser(
          previousActive.userId,
        );
      } catch (_) {}
    }
  }

  Future<void> _markAccountNeedsLogin(int userId) async {
    ++_authGeneration;
    switchingAccount = false;
    vault = vault.markTokenStatus(userId, TokenStatus.needsLogin);
    await _saveVault();
    this._emitChange();
  }

  Future<void> _logout() async {
    await signOutAll();
  }
}
