import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/telegram/telegram_auth_bridge.dart';
import '../../core/telegram/telegram_client_exceptions.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';
import 'tdlib_auto_authorization_models.dart';

enum TdlibSessionStatus {
  signedOut,
  checking,
  unavailable,
  authorizationRequired,
  waitCode,
  waitPassword,
  mismatch,
  ready,
  error,
}

@immutable
class TdlibSessionState {
  const TdlibSessionState({
    this.status = TdlibSessionStatus.checking,
    this.message,
    this.authorizationState,
    this.localTelegramUserId,
    this.auto = const TdlibAutoAuthorizationState(),
  });

  final TdlibSessionStatus status;
  final String? message;
  final String? authorizationState;
  final int? localTelegramUserId;
  final TdlibAutoAuthorizationState auto;

  bool get ready => status == TdlibSessionStatus.ready;
  bool get canEnterDrive =>
      status == TdlibSessionStatus.ready ||
      status == TdlibSessionStatus.signedOut;

  TdlibSessionState copyWith({
    TdlibSessionStatus? status,
    String? message,
    bool clearMessage = false,
    String? authorizationState,
    int? localTelegramUserId,
    TdlibAutoAuthorizationState? auto,
  }) {
    return TdlibSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      authorizationState: authorizationState ?? this.authorizationState,
      localTelegramUserId: localTelegramUserId ?? this.localTelegramUserId,
      auto: auto ?? this.auto,
    );
  }
}

final tdlibSessionControllerProvider =
    ChangeNotifierProvider<TdlibSessionController>((ref) {
      final controller = TdlibSessionController(
        auth: ref.read(authControllerProvider),
        repo: ref.read(authRepositoryProvider),
        telegram: ref.read(telegramTransferServiceProvider),
      );
      ref.onDispose(controller.dispose);
      unawaited(controller.check());
      return controller;
    });

class TdlibSessionController extends ChangeNotifier {
  TdlibSessionController({
    required AuthController auth,
    required AuthRepository repo,
    required TelegramTransferService telegram,
    TelegramAuthBridge? bridge,
  }) : _auth = auth,
       _repo = repo,
       _telegram = telegram,
       _bridge = bridge ?? TelegramAuthBridge() {
    _auth.addListener(_handleAuthChanged);
  }

  final AuthController _auth;
  final AuthRepository _repo;
  final TelegramTransferService _telegram;
  final TelegramAuthBridge _bridge;
  final _uuid = const Uuid();
  TdlibSessionState state = const TdlibSessionState();
  Future<void>? _checking;
  Timer? _authDebounce;
  Timer? _otpTimer;
  int _autoRunId = 0;
  Future<void>? _autoTask;
  String? _autoPhoneNumber;
  int? _autoTelegramUserId;
  DateTime? _otpResolveStartedAt;
  String? _ephemeralCloudPassword;

  bool get isReadyForActiveUser =>
      !_auth.isAuthenticated || state.status == TdlibSessionStatus.ready;

  Future<void> authorizeAutomatically({
    required String phoneNumber,
    required int telegramUserId,
    String? ephemeralCloudPassword,
    bool restartOtpWindow = false,
  }) async {
    final current = _autoTask;
    if (current != null && !restartOtpWindow) return current;
    _cancelAutomation(clearSecret: false);
    _autoPhoneNumber = phoneNumber;
    _autoTelegramUserId = telegramUserId;
    if (restartOtpWindow) {
      _otpResolveStartedAt = DateTime.now().toUtc();
    }
    if (ephemeralCloudPassword != null && ephemeralCloudPassword.isNotEmpty) {
      _ephemeralCloudPassword = ephemeralCloudPassword;
    }
    final runId = ++_autoRunId;
    final task = _runAutomaticAuthorization(
      runId,
      restartOtpWindow: restartOtpWindow,
    );
    _autoTask = task;
    try {
      await task;
    } finally {
      if (identical(_autoTask, task)) _autoTask = null;
    }
  }

  Future<void> submitManualCodeForAutomation(String code) async {
    _cancelOtpTimer();
    final runId = ++_autoRunId;
    _setAutoStage(TdlibAutoAuthStage.submittingCode);
    try {
      await submitCode(code);
      await _advanceAutomaticAuthorization(runId);
    } catch (_) {
      _setAutoStage(
        TdlibAutoAuthStage.manualCodeRequired,
        error: 'Telegram rejected that code.',
        otpSecondsRemaining: 0,
      );
    }
  }

  void cancelAutomation({bool clearSecret = true}) {
    _cancelAutomation(clearSecret: clearSecret);
    state = state.copyWith(auto: const TdlibAutoAuthorizationState());
    notifyListeners();
  }

  Future<void> check({bool force = false}) async {
    final inFlight = _checking;
    if (inFlight != null && !force) return inFlight;
    final task = _check();
    _checking = task;
    try {
      await task;
    } finally {
      if (identical(_checking, task)) _checking = null;
    }
  }

  Future<void> submitPhoneNumber(String phoneNumber) async {
    await _configureActiveUser();
    await _bridge.setPhoneNumber(phoneNumber);
    await check(force: true);
  }

  Future<void> submitCode(String code) async {
    await _configureActiveUser();
    await _bridge.checkCode(code);
    await check(force: true);
  }

  Future<void> submitPassword(String password) async {
    await _configureActiveUser();
    await _bridge.checkPassword(password);
    await check(force: true);
  }

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
      _clearEphemeralCloudPassword();
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
          final phone = _autoPhoneNumber;
          if (phone == null || phone.isEmpty) {
            _setAutoStage(
              TdlibAutoAuthStage.failed,
              error: 'Could not confirm your Telegram phone number.',
              canRetryAutomation: true,
            );
            _clearEphemeralCloudPassword();
            return;
          }
          _setAutoStage(TdlibAutoAuthStage.submittingPhoneNumber);
          _otpResolveStartedAt = DateTime.now().toUtc();
          await submitPhoneNumber(phone);
        case TdlibSessionStatus.waitCode:
          await _waitForAutomaticCode(runId);
          return;
        case TdlibSessionStatus.waitPassword:
          await _submitAutomaticPasswordOrFallback(runId);
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
          _clearEphemeralCloudPassword();
          return;
        case TdlibSessionStatus.mismatch:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error:
                'This device is linked to a different Telegram account. Please reconnect with the correct account.',
          );
          _clearEphemeralCloudPassword();
          return;
        case TdlibSessionStatus.error:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error: 'TDLib authorization failed. Please try again.',
            canRetryAutomation: true,
            canEnterCodeManually: true,
          );
          _clearEphemeralCloudPassword();
          return;
        case TdlibSessionStatus.signedOut:
          _setAutoStage(
            TdlibAutoAuthStage.failed,
            error: 'Sign in before authorizing TDLib.',
          );
          _clearEphemeralCloudPassword();
          return;
      }
    }
    if (_isRunActive(runId)) {
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error: 'TDLib authorization did not settle. Please try again.',
        canRetryAutomation: true,
      );
      _clearEphemeralCloudPassword();
    }
  }

  Future<void> _waitForAutomaticCode(int runId) async {
    final phone = _autoPhoneNumber;
    final telegramUserId = _autoTelegramUserId;
    if (phone == null || telegramUserId == null) {
      _setAutoStage(
        TdlibAutoAuthStage.manualCodeRequired,
        error: 'Telegram code needed.',
        otpSecondsRemaining: 0,
      );
      return;
    }
    final startedAt = _otpResolveStartedAt ?? DateTime.now().toUtc();
    final nonce = _uuid.v4();
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
          telegramUserId: telegramUserId,
          phoneNumber: phone,
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
          _clearEphemeralCloudPassword();
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

  Future<void> _submitAutomaticPasswordOrFallback(int runId) async {
    _setAutoStage(TdlibAutoAuthStage.waitingForPassword);
    final password = _ephemeralCloudPassword;
    if (password == null || password.isEmpty) {
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error:
            'Cloud password verification could not be reused. Please sign in again.',
        canRetryAutomation: true,
      );
      return;
    }
    _setAutoStage(TdlibAutoAuthStage.submittingPassword);
    try {
      await submitPassword(password);
    } catch (_) {
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error:
            'Cloud password verification could not be reused. Please sign in again.',
        canRetryAutomation: true,
      );
      return;
    } finally {
      _clearEphemeralCloudPassword();
    }
    await _advanceAutomaticAuthorization(runId);
  }

  Future<void> _verifyAuthorizedAccount(int runId) async {
    final telegramUserId = _autoTelegramUserId;
    if (telegramUserId == null) {
      _setAutoStage(
        TdlibAutoAuthStage.failed,
        error: 'TDLib is authorized but could not confirm the account.',
      );
      _clearEphemeralCloudPassword();
      return;
    }
    _setAutoStage(TdlibAutoAuthStage.verifyingAccount);
    await _bridge.assertMatchesBackend(telegramUserId);
    if (!_isRunActive(runId)) return;
    _setAutoStage(TdlibAutoAuthStage.authorized);
    _clearEphemeralCloudPassword();
  }

  Future<void> _check() async {
    if (!_auth.isAuthenticated || _auth.user == null) {
      state = const TdlibSessionState(status: TdlibSessionStatus.signedOut);
      notifyListeners();
      return;
    }
    state = state.copyWith(
      status: TdlibSessionStatus.checking,
      clearMessage: true,
    );
    notifyListeners();
    try {
      if (!_auth.directTelegramUploadEnabled ||
          !_auth.directTelegramDownloadEnabled) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.unavailable,
          message:
              'TeleDrive requires local TDLib transfer. This backend is not advertising client-direct transfer yet.',
        );
        notifyListeners();
        return;
      }
      if (!await _telegram.isAvailable) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.unavailable,
          message:
              'TeleDrive requires a supported 64-bit Android device for local TDLib file transfer.',
        );
        notifyListeners();
        return;
      }
      if (!AppConfig.telegramApiConfigured) {
        state = const TdlibSessionState(
          status: TdlibSessionStatus.unavailable,
          message:
              'Local TDLib requires TELEGRAM_API_ID and TELEGRAM_API_HASH.',
        );
        notifyListeners();
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
        notifyListeners();
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
        notifyListeners();
        return;
      }
      if (localId != expected) {
        state = TdlibSessionState(
          status: TdlibSessionStatus.mismatch,
          localTelegramUserId: localId,
          message:
              'Local Telegram account does not match the active TeleDrive account.',
        );
        notifyListeners();
        return;
      }
      state = TdlibSessionState(
        status: TdlibSessionStatus.ready,
        localTelegramUserId: localId,
        message:
            'Local TDLib is ready. The backend stores metadata and Telegram references only for private transfers.',
      );
      notifyListeners();
    } catch (err) {
      state = TdlibSessionState(
        status: err is TelegramAccountMismatchException
            ? TdlibSessionStatus.mismatch
            : err is TelegramClientUnavailableException
            ? TdlibSessionStatus.unavailable
            : TdlibSessionStatus.error,
        message: _messageForError(err),
      );
      notifyListeners();
    }
  }

  bool _isRunActive(int runId) => _autoRunId == runId;

  void _cancelAutomation({required bool clearSecret}) {
    _autoRunId++;
    _autoTask = null;
    _otpResolveStartedAt = null;
    _cancelOtpTimer();
    if (clearSecret) _clearEphemeralCloudPassword();
  }

  void _cancelOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = null;
  }

  void _clearEphemeralCloudPassword() {
    _ephemeralCloudPassword = null;
    _auth.clearEphemeralTelegramCloudPassword();
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
        canEnterPasswordManually: canEnterPasswordManually,
      ),
    );
    notifyListeners();
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

  void _handleAuthChanged() {
    if (!_auth.isAuthenticated) {
      _cancelAutomation(clearSecret: true);
    }
    _authDebounce?.cancel();
    _authDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(check(force: true));
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    _cancelAutomation(clearSecret: true);
    _authDebounce?.cancel();
    super.dispose();
  }
}
