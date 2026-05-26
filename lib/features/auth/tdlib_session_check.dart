part of 'tdlib_session_controller.dart';

extension _TdlibSessionCheck on TdlibSessionController {
  Future<void> _check() async {
    if (!_auth.isAuthenticated || _auth.user == null) {
      state = const TdlibSessionState(status: TdlibSessionStatus.signedOut);
      _emitChange();
      return;
    }
    state = state.copyWith(
      status: TdlibSessionStatus.checking,
      clearMessage: true,
    );
    _emitChange();
    try {
      if (!_auth.directTelegramUploadEnabled ||
          !_auth.directTelegramDownloadEnabled) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.unavailable,
          message:
              'TeleDrive requires local TDLib transfer. This backend is not advertising client-direct transfer yet.',
        );
        _emitChange();
        return;
      }
      if (!await _telegram.isAvailable) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.unavailable,
          message:
              'TeleDrive requires a supported 64-bit Android device for local TDLib file transfer.',
        );
        _emitChange();
        return;
      }
      if (!AppConfig.telegramApiConfigured) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.unavailable,
          message:
              'Local TDLib requires TELEGRAM_API_ID and TELEGRAM_API_HASH.',
        );
        _emitChange();
        return;
      }
      await _configureActiveUser();
      final health = await _telegram.health();
      final authState = '${health['authorizationState'] ?? ''}';
      if (health['authorized'] != true) {
        state = TdlibSessionState(
          status: _statusFromAuthorizationState(authState),
          authorizationState: authState,
          message:
              'Reconnect Telegram on this device. File bytes are transferred locally through TDLib; no backend upload fallback is maintained.',
        );
        _emitChange();
        return;
      }
      final me = await _telegram.getMe();
      final localId = _intish(me['telegramUserId'] ?? me['id']);
      final expected = _auth.user!.telegramId != 0
          ? _auth.user!.telegramId
          : _auth.activeAccount?.telegramId ?? 0;
      if (expected == 0 || localId == null) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.error,
          message: 'TDLib is authorized but could not confirm the account.',
        );
        _emitChange();
        return;
      }
      if (localId != expected) {
        state = TdlibSessionState(
          status: TdlibSessionStatus.mismatch,
          localTelegramUserId: localId,
          message:
              'Local Telegram account does not match the active TeleDrive account.',
        );
        _emitChange();
        return;
      }
      state = TdlibSessionState(
        status: TdlibSessionStatus.ready,
        localTelegramUserId: localId,
        message:
            'Local TDLib is ready. The backend stores metadata and Telegram references only for private transfers.',
      );
      _emitChange();
    } catch (err) {
      state = TdlibSessionState(
        status: err is TelegramAccountMismatchException
            ? TdlibSessionStatus.mismatch
            : err is TelegramClientUnavailableException
            ? TdlibSessionStatus.unavailable
            : TdlibSessionStatus.error,
        message: _messageForError(err),
      );
      _emitChange();
    }
  }

  bool _isRunActive(int runId) {
    if (_autoRunId != runId) return false;
    final run = _activeRun;
    if (run == null) return false;
    final activeBackendUserId = _auth.user?.userId;
    if (activeBackendUserId != null &&
        activeBackendUserId != 0 &&
        activeBackendUserId != run.backendUserId) {
      return false;
    }
    return true;
  }

  void _cancelAutomation({required bool clearSecret}) {
    _autoRunId++;
    _autoTask = null;
    final run = _activeRun;
    _activeRun = null;
    _cancelOtpTimer();
    if (clearSecret && run != null) {
      _auth.clearEphemeralTelegramCloudPassword(
        telegramUserId: run.telegramUserId,
      );
    } else if (clearSecret) {
      _auth.clearEphemeralTelegramCloudPassword();
    }
  }

  void _cancelOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = null;
  }

  void _showManualCodeRequired({String? error}) {
    _cancelOtpTimer();
    _setAutoStage(
      TdlibAutoAuthStage.manualCodeRequired,
      error: error,
      otpSecondsRemaining: 0,
    );
  }

  void _setWaitingForCode(DateTime deadline) {
    final remainingMs = deadline
        .difference(DateTime.now().toUtc())
        .inMilliseconds;
    final seconds = math.max(0, (remainingMs / 1000).ceil());
    final elapsed = 30 - seconds;
    final progress = math.min(65, 45 + ((elapsed / 30) * 20).round());
    _setAutoStage(
      TdlibAutoAuthStage.waitingForCode,
      progressPercent: progress,
      otpSecondsRemaining: seconds,
    );
  }

  void _setAutoStage(
    TdlibAutoAuthStage stage, {
    int? progressPercent,
    int? otpSecondsRemaining,
    String? error,
    bool canRetryAutomation = false,
    bool canEnterCodeManually = false,
    bool canEnterPasswordManually = false,
  }) {
    final defaults = _defaultAutoCopy(stage);
    state = state.copyWith(
      auto: defaults.copyWith(
        progressPercent: progressPercent,
        otpSecondsRemaining: otpSecondsRemaining,
        clearOtpSecondsRemaining:
            otpSecondsRemaining == null &&
            stage != TdlibAutoAuthStage.waitingForCode,
        error: error,
        clearError: error == null,
        canRetryAutomation:
            canRetryAutomation ||
            stage == TdlibAutoAuthStage.manualCodeRequired,
        canEnterCodeManually:
            canEnterCodeManually ||
            stage == TdlibAutoAuthStage.manualCodeRequired,
        canEnterPasswordManually:
            canEnterPasswordManually ||
            stage == TdlibAutoAuthStage.manualPasswordRequired,
      ),
    );
    _emitChange();
  }

  TdlibAutoAuthorizationState _defaultAutoCopy(TdlibAutoAuthStage stage) {
    final (progress, title, subtitle) = switch (stage) {
      TdlibAutoAuthStage.idle => (
        0,
        'Authorize TDLib',
        'Setting up secure local transfer on this device.',
      ),
      TdlibAutoAuthStage.checkingExistingSession => (
        8,
        'Checking local session',
        'Confirming whether this device is already linked.',
      ),
      TdlibAutoAuthStage.preparingEngine => (
        18,
        'Preparing local TDLib engine',
        'Starting the secure transfer runtime.',
      ),
      TdlibAutoAuthStage.submittingPhoneNumber => (
        32,
        'Confirming Telegram account',
        'Submitting your phone number securely.',
      ),
      TdlibAutoAuthStage.waitingForCode => (
        45,
        'Waiting for Telegram verification',
        'Detecting the latest Telegram login code.',
      ),
      TdlibAutoAuthStage.submittingCode => (
        72,
        'Confirming Telegram verification',
        'Submitting the detected code.',
      ),
      TdlibAutoAuthStage.waitingForPassword => (
        78,
        'Securing local session',
        'Checking whether cloud password verification is required.',
      ),
      TdlibAutoAuthStage.submittingPassword => (
        84,
        'Securing local session',
        'Completing cloud password verification.',
      ),
      TdlibAutoAuthStage.verifyingAccount => (
        92,
        'Finalizing transfer channel',
        'Verifying this device matches your Telegram account.',
      ),
      TdlibAutoAuthStage.authorized => (
        100,
        'TDLib authorized',
        'Your secure local transfer channel is ready.',
      ),
      TdlibAutoAuthStage.manualCodeRequired => (
        65,
        'Telegram code needed',
        'Enter the code manually or try automatic detection again.',
      ),
      TdlibAutoAuthStage.manualPasswordRequired => (
        78,
        'Telegram cloud password needed',
        'Enter your two-step verification password to finish setup.',
      ),
      TdlibAutoAuthStage.failed => (
        state.auto.progressPercent,
        'Authorization needs attention',
        'We could not finish local TDLib authorization.',
      ),
    };
    return TdlibAutoAuthorizationState(
      stage: stage,
      progressPercent: progress,
      title: title,
      subtitle: subtitle,
      canRetryAutomation: false,
      canEnterCodeManually: false,
      canEnterPasswordManually: false,
    );
  }

  String _friendlyAutomationError(Object err) {
    if (err is TelegramAccountMismatchException) {
      return 'This device is linked to a different Telegram account. Please reconnect with the correct account.';
    }
    if (err is TelegramClientUnavailableException) {
      return 'TDLib is unavailable on this device build. Please reinstall the supported app build.';
    }
    return 'TDLib authorization failed. Please try again.';
  }

  Future<void> _configureActiveUser() async {
    final user = _auth.user;
    final telegramId = user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    if (user == null || telegramId == 0) {
      throw const TelegramClientUnavailableException(
        'Connect Telegram before using TeleDrive transfer.',
        code: 'tdlib_not_connected',
      );
    }
    await _telegram.configure(
      backendUserId: '${user.userId}',
      telegramUserId: telegramId,
    );
  }

  TdlibSessionStatus _statusFromAuthorizationState(String value) {
    if (value == 'authorizationStateWaitCode') {
      return TdlibSessionStatus.waitCode;
    }
    if (value == 'authorizationStateWaitPassword') {
      return TdlibSessionStatus.waitPassword;
    }
    return TdlibSessionStatus.authorizationRequired;
  }

  String _messageForError(Object err) {
    if (err is TelegramClientUnavailableException &&
        (err.code == 'tdlib_unavailable' ||
            err.code == 'tdlib_bridge_missing')) {
      return 'TeleDrive requires a supported 64-bit Android device for local TDLib file transfer.';
    }
    final raw = '$err'.trim();
    return raw.isEmpty
        ? 'TDLib session check failed. Reconnect Telegram on this device.'
        : raw;
  }

  int? _intish(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
