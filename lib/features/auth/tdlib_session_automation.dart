part of 'tdlib_session_controller.dart';

extension _TdlibSessionAutomation on TdlibSessionController {
  Future<void> _runAutomaticAuthorization(
    int runId, {
    required bool restartOtpWindow,
  }) async {
    try {
      if (!restartOtpWindow) {
        _setAutoStage(TdlibAutoAuthStage.checkingExistingSession);
        if (!_isRunActive(runId)) return;
        _setAutoStage(TdlibAutoAuthStage.preparingEngine);
      }
      await check(force: true);
      await _advanceAutomaticAuthorization(runId);
    } catch (err) {
      if (!_isRunActive(runId)) return;
      final message = _friendlyAutomationError(err);
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error: message,
        canRetryAutomation: true,
        canEnterCodeManually: state.status == TdlibSessionStatus.waitCode,
      );
    }
  }

  Future<void> _advanceAutomaticAuthorization(int runId) async {
    var guard = 0;
    while (_isRunActive(runId) && guard++ < 12) {
      switch (state.status) {
        case TdlibSessionStatus.ready:
          await _verifyAuthorizedAccount(runId);
          return;
        case TdlibSessionStatus.authorizationRequired:
          final run = _activeRun;
          if (run == null || run.phoneNumber.isEmpty) {
            _setAutoStage(
              TdlibAutoAuthStage.failed,
              error: 'Could not confirm your Telegram phone number.',
              canRetryAutomation: true,
            );
            return;
          }
          _setAutoStage(TdlibAutoAuthStage.submittingPhoneNumber);
          _activeRun = run.copyWith(phoneSubmittedAt: DateTime.now().toUtc());
          await submitPhoneNumber(run.phoneNumber);
        case TdlibSessionStatus.waitCode:
          await _waitForAutomaticCode(runId);
          return;
        case TdlibSessionStatus.waitPassword:
          await _resolvePasswordAndSubmit(runId);
          return;
        case TdlibSessionStatus.checking:
          await check(force: true);
        case TdlibSessionStatus.unavailable:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error:
                'TDLib is unavailable on this device build. Please reinstall the supported app build.',
            canRetryAutomation: true,
          );
          return;
        case TdlibSessionStatus.mismatch:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error:
                'This device is linked to a different Telegram account. Please reconnect with the correct account.',
          );
          return;
        case TdlibSessionStatus.error:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error: 'TDLib authorization failed. Please try again.',
            canRetryAutomation: true,
            canEnterCodeManually: true,
          );
          return;
        case TdlibSessionStatus.signedOut:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error: 'Sign in before authorizing TDLib.',
          );
          return;
      }
    }
    if (_isRunActive(runId)) {
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error: 'TDLib authorization did not settle. Please try again.',
        canRetryAutomation: true,
      );
    }
  }

  Future<void> _waitForAutomaticCode(int runId) async {
    final run = _activeRun;
    if (run == null) {
      _setAutoStage(
        TdlibAutoAuthStage.manualCodeRequired,
        error: 'Telegram code needed.',
        otpSecondsRemaining: 0,
      );
      return;
    }
    final startedAt = run.phoneSubmittedAt;
    final nonce = run.nonce;
    final deadline = startedAt.add(const Duration(seconds: 30));
    final rejectedAutoCodes = <String>{};
    _setWaitingForCode(deadline);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunActive(runId)) return;
      _setWaitingForCode(deadline);
    });

    while (_isRunActive(runId)) {
      final now = DateTime.now().toUtc();
      if (!now.isBefore(deadline)) break;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_isRunActive(runId)) return;
      if (!DateTime.now().toUtc().isBefore(deadline)) break;
      final TdlibCodeResolveResult result;
      try {
        result = await _repo.resolveTdlibCode(
          telegramUserId: run.telegramUserId,
          phoneNumber: run.phoneNumber,
          startedAt: startedAt,
          nonce: nonce,
        );
      } catch (_) {
        _showManualCodeRequired(
          error: 'We could not detect the latest Telegram code automatically.',
        );
        return;
      }
      if (!_isRunActive(runId)) return;
      switch (result.status) {
        case TdlibCodeResolveStatus.found:
          final code = result.code;
          if (code == null || code.isEmpty) continue;
          if (rejectedAutoCodes.contains(code)) continue;
          _setAutoStage(TdlibAutoAuthStage.submittingCode);
          try {
            await submitCode(code);
          } catch (_) {
            rejectedAutoCodes.add(code);
            _setWaitingForCode(deadline);
            continue;
          }
          _cancelOtpTimer();
          await _advanceAutomaticAuthorization(runId);
          return;
        case TdlibCodeResolveStatus.pending:
          continue;
        case TdlibCodeResolveStatus.expired:
        case TdlibCodeResolveStatus.manualRequired:
          _showManualCodeRequired();
          return;
        case TdlibCodeResolveStatus.wrongAccount:
          _cancelOtpTimer();
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error:
                'This device is linked to a different Telegram account. Please reconnect with the correct account.',
          );
          return;
        case TdlibCodeResolveStatus.rateLimited:
        case TdlibCodeResolveStatus.error:
          _showManualCodeRequired(
            error:
                'We could not detect the latest Telegram code automatically.',
          );
          return;
      }
    }
    if (_isRunActive(runId)) _showManualCodeRequired();
  }

  Future<void> _resolvePasswordAndSubmit(int runId) async {
    final run = _activeRun;
    if (run == null) {
      _setAutoStage(
        TdlibAutoAuthStage.manualPasswordRequired,
        error: 'Cloud password verification needed.',
      );
      return;
    }
    _setAutoStage(TdlibAutoAuthStage.waitingForPassword);
    final ephemeral = _auth.takeEphemeralTelegramCloudPassword(
      run.telegramUserId,
    );
    String? candidate = (ephemeral != null && ephemeral.isNotEmpty)
        ? ephemeral
        : null;
    var fromStorage = false;
    if (candidate == null) {
      try {
        candidate = await _storage.readTelegramCloudPassword(
          backendUserId: run.backendUserId,
          telegramUserId: run.telegramUserId,
        );
        fromStorage = candidate != null && candidate.isNotEmpty;
      } catch (_) {
        candidate = null;
      }
    }
    if (!_isRunActive(runId)) return;
    if (candidate == null || candidate.isEmpty) {
      _setAutoStage(TdlibAutoAuthStage.manualPasswordRequired);
      return;
    }
    _setAutoStage(TdlibAutoAuthStage.submittingPassword);
    try {
      await submitPassword(candidate);
    } catch (_) {
      if (fromStorage) {
        try {
          await _storage.deleteTelegramCloudPassword(
            backendUserId: run.backendUserId,
            telegramUserId: run.telegramUserId,
          );
        } catch (_) {}
      }
      if (!_isRunActive(runId)) return;
      _setAutoStage(
        TdlibAutoAuthStage.manualPasswordRequired,
        error: 'Saved password was rejected. Enter your cloud password.',
      );
      return;
    }
    if (!fromStorage) {
      try {
        await _storage.saveTelegramCloudPassword(
          backendUserId: run.backendUserId,
          telegramUserId: run.telegramUserId,
          password: candidate,
        );
      } catch (_) {}
    }
    if (!_isRunActive(runId)) return;
    await _advanceAutomaticAuthorization(runId);
  }

  Future<void> _verifyAuthorizedAccount(int runId) async {
    final run = _activeRun;
    final telegramUserId = run?.telegramUserId;
    if (telegramUserId == null || telegramUserId == 0) {
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error: 'TDLib is authorized but could not confirm the account.',
      );
      return;
    }
    _setAutoStage(TdlibAutoAuthStage.verifyingAccount);
    await _bridge.assertMatchesBackend(telegramUserId);
    if (!_isRunActive(runId)) return;
    _setAutoStage(TdlibAutoAuthStage.authorized);
  }
}
