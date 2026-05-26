part of 'auth_controller.dart';

extension _AuthControllerSessionActions on AuthController {
  Future<void> _bootstrap() async {
    loading = true;
    this._emitChange(); // ignore: unnecessary_this
    try {
      error = null;
      vault = await this._loadVaultWithLegacyMigration(); // ignore: unnecessary_this
      if (vault.accounts.isEmpty) {
        _repo.setApiToken(null);
        this._clearSessionState(clearVault: false); // ignore: unnecessary_this
        return;
      }
      await this._restoreBestAccount(); // ignore: unnecessary_this
      unawaited(this._refreshSavedAccountSnapshots()); // ignore: unnecessary_this
    } catch (err) {
      _repo.setApiToken(null);
      this._clearSessionState(clearVault: false);
      error = _repo.api.errorMessage(err, 'Auth bootstrap failed.');
    } finally {
      loading = false;
      this._emitChange();
    }
  }

  Future<void> _login(
    String nextToken, {
    Map<String, dynamic>? authPayload,
  }) async {
    error = null;
    if (_repo.isExpired(nextToken)) throw Exception('Invalid token received.');
    final bootstrap = await _repo.bootstrapWithToken(
      nextToken,
      includeDrive: true,
    );
    await this._commitActiveAccount(nextToken, bootstrap); // ignore: unnecessary_this
    this._emitChange(); // ignore: unnecessary_this
  }

  Future<void> _switchToAccount(int userId) async {
    final selected = vault.accounts
        .where((account) => account.userId == userId)
        .firstOrNull;
    if (selected == null || selected.userId == activeAccount?.userId) return;
    if (selected.tokenStatus != TokenStatus.valid ||
        _repo.isExpired(selected.token)) {
      vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
      await _repo.saveVault(vault);
      _emitChange();
      throw Exception('Session expired. Please log in again.');
    }

    switchingAccount = true;
    _emitChange();
    try {
      final bootstrap = await _repo.bootstrapWithToken(
        selected.token,
        includeDrive: true,
      );
      if (!this._bootstrapMatchesAccount(selected, bootstrap)) { // ignore: unnecessary_this
        vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
        await _repo.saveVault(vault);
        throw Exception('Session expired. Please log in again.');
      }
      await this._commitActiveAccount(selected.token, bootstrap, existing: selected);
    } on DioException catch (err) {
      if (err.response?.statusCode == 401) {
        vault = vault.markTokenStatus(selected.userId, TokenStatus.needsLogin);
        await _repo.saveVault(vault);
        throw Exception('Session expired. Please log in again.');
      }
      rethrow;
    } finally {
      switchingAccount = false;
      this._emitChange();
    }
  }

  Future<bool> _removeAccountFromDevice(int userId) async {
    final wasActive = activeAccount?.userId == userId;
    final removed = vault.accountByUserId(userId);
    vault = vault.remove(userId);
    await _repo.saveVault(vault);
    await _repo.deleteCachedProfilePhoto(userId);
    if (removed != null && removed.telegramId != 0) {
      try {
        await _storage.deleteTelegramCloudPassword(
          backendUserId: removed.userId,
          telegramUserId: removed.telegramId,
        );
      } catch (_) {}
    }
    clearEphemeralTelegramCloudPassword(telegramUserId: removed?.telegramId);
    if (!wasActive) {
      this._emitChange();
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

  Future<void> _signOutAll() async {
    final previousActive = activeAccount;
    await _repo.clearAllAuthStorage();
    if (previousActive != null) {
      try {
        await _storage.deleteAllTelegramCloudPasswordsForUser(
          previousActive.userId,
        );
      } catch (_) {}
    }
    clearEphemeralTelegramCloudPassword();
    this._clearPendingAccountAuthorization();
    this._clearSessionState();
    this._emitChange();
  }

  Future<void> _markAccountNeedsLogin(int userId) async {
    vault = vault.markTokenStatus(userId, TokenStatus.needsLogin);
    await _repo.saveVault(vault);
    this._emitChange();
  }

  Future<void> _logout() async {
    await signOutAll();
  }
}
