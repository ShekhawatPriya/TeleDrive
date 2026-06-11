part of 'auth_controller.dart';

extension _AuthControllerPending on AuthController {
  void _rememberEphemeralTelegramCloudPassword(
    int telegramUserId,
    String value,
  ) {
    if (telegramUserId == 0 || value.isEmpty) return;
    _ephemeralCloudPasswords[telegramUserId] = value;
  }

  String? _takeEphemeralTelegramCloudPassword(int telegramUserId) {
    return _ephemeralCloudPasswords.remove(telegramUserId);
  }

  void _clearEphemeralTelegramCloudPassword({int? telegramUserId}) {
    if (telegramUserId == null) {
      _ephemeralCloudPasswords.clear();
    } else {
      _ephemeralCloudPasswords.remove(telegramUserId);
    }
  }

  void _beginPendingAccountAuthorization({
    required PendingTdlibMode mode,
    required int candidateUserId,
    required int candidateTelegramId,
    required String candidatePhone,
    String? returnTo,
  }) {
    pendingTdlibMode = mode;
    pendingPreviousUserId = mode == PendingTdlibMode.normalLogin
        ? null
        : activeAccount?.userId;
    pendingCandidateUserId = candidateUserId == 0 ? null : candidateUserId;
    pendingCandidateTelegramId = candidateTelegramId == 0
        ? null
        : candidateTelegramId;
    pendingCandidatePhone = candidatePhone.isEmpty ? null : candidatePhone;
    pendingReturnTo = returnTo;
    _emitChange();
  }

  void _updatePendingAccountCandidate({
    required int candidateUserId,
    required int candidateTelegramId,
  }) {
    if (pendingTdlibMode == null) return;
    if (candidateUserId != 0) pendingCandidateUserId = candidateUserId;
    if (candidateTelegramId != 0) {
      pendingCandidateTelegramId = candidateTelegramId;
    }
  }

  void _clearPendingAccountAuthorization() {
    pendingTdlibMode = null;
    pendingPreviousUserId = null;
    pendingCandidateUserId = null;
    pendingCandidateTelegramId = null;
    pendingCandidatePhone = null;
    pendingReturnTo = null;
  }

  String _commitPendingAccountAuthorization() {
    final returnTo = pendingReturnTo;
    final candidateTelegramId = pendingCandidateTelegramId;
    if (candidateTelegramId != null) {
      clearEphemeralTelegramCloudPassword(telegramUserId: candidateTelegramId);
    }
    _clearPendingAccountAuthorization();
    this._emitChange();
    unawaited(this._retryPendingDirectCommitsForActiveAccount());
    if (needsCommunityOnboarding) return '/community-setup';
    if (returnTo != null &&
        returnTo.isNotEmpty &&
        returnTo != '/' &&
        returnTo != '/welcome' &&
        returnTo != '/login' &&
        returnTo != '/tdlib-session' &&
        returnTo != '/community-setup') {
      return returnTo;
    }
    return '/drive';
  }

  Future<String> _abortPendingTdlibAuthorization() async {
    final mode = pendingTdlibMode;
    final previousUserId = pendingPreviousUserId;
    final candidateTelegramId = pendingCandidateTelegramId;
    final candidateUserId = pendingCandidateUserId;
    final returnTo = pendingReturnTo;
    if (candidateTelegramId != null) {
      clearEphemeralTelegramCloudPassword(telegramUserId: candidateTelegramId);
    }
    _clearPendingAccountAuthorization();
    if (mode == null && isAuthenticated) {
      // Not inside a login transaction: the user opened TDLib setup from an
      // already-restored session (e.g. after an app restart) and backed out.
      // Keep them signed in instead of nuking the whole vault.
      this._emitChange();
      if (returnTo != null &&
          returnTo.isNotEmpty &&
          returnTo != '/tdlib-session' &&
          returnTo != '/login' &&
          returnTo != '/welcome' &&
          returnTo != '/') {
        return returnTo;
      }
      return '/drive';
    }
    if ((mode == PendingTdlibMode.addAccount ||
            mode == PendingTdlibMode.reauthenticateAccount) &&
        previousUserId != null &&
        previousUserId != candidateUserId) {
      try {
        await switchToAccount(previousUserId);
        this._emitChange();
        if (returnTo != null &&
            returnTo.isNotEmpty &&
            returnTo != '/tdlib-session' &&
            returnTo != '/login' &&
            returnTo != '/welcome' &&
            returnTo != '/') {
          return returnTo;
        }
        return '/drive';
      } catch (_) {
        // Previous account no longer usable; fall through to sign-out path.
      }
    }
    if (candidateUserId != null) {
      final activeUserId = activeAccount?.userId;
      if (activeUserId == candidateUserId) {
        final fallback = vault
            .validAccountsByRecent()
            .where((account) => account.userId != candidateUserId)
            .firstOrNull;
        if (fallback != null) {
          try {
            await switchToAccount(fallback.userId);
            this._emitChange();
            return '/drive';
          } catch (_) {}
        }
      }
    }
    await signOutAll();
    return '/welcome';
  }
}
