import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/telegram/telegram_auth_bridge.dart';
import '../../core/telegram/telegram_client_exceptions.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';
import 'tdlib_auto_authorization_models.dart';
import 'tdlib_session_models.dart';

export 'tdlib_session_models.dart';

part 'tdlib_session_automation.dart';
part 'tdlib_session_check.dart';

final tdlibSessionControllerProvider =
    ChangeNotifierProvider<TdlibSessionController>((ref) {
      final controller = TdlibSessionController(
        auth: ref.read(authControllerProvider),
        repo: ref.read(authRepositoryProvider),
        telegram: ref.read(telegramTransferServiceProvider),
        storage: ref.read(secureStorageProvider),
      );
      ref.onDispose(controller.dispose);
      unawaited(controller.check());
      return controller;
    });

class TdlibSessionController extends ChangeNotifier {
  TdlibSessionController({
    required this._auth,
    required this._repo,
    required this._telegram,
    required this._storage,
    TelegramAuthBridge? bridge,
  }) : _bridge = bridge ?? TelegramAuthBridge() {
    _auth.addListener(_handleAuthChanged);
  }

  final AuthController _auth;
  final AuthRepository _repo;
  final TelegramTransferService _telegram;
  final SecureStorageService _storage;
  final TelegramAuthBridge _bridge;
  final _uuid = const Uuid();
  TdlibSessionState state = const TdlibSessionState();
  Future<void>? _checking;
  Timer? _authDebounce;
  Timer? _otpTimer;
  int _autoRunId = 0;
  Future<void>? _autoTask;
  TdlibAuthorizationRun? _activeRun;

  bool get isReadyForActiveUser =>
      !_auth.isAuthenticated || state.status == TdlibSessionStatus.ready;

  /// True only when the user genuinely needs to interact with the TDLib
  /// authorization flow. Transient states like `checking`, terminal states like
  /// `error` or `unavailable`, and `signedOut` are NOT included — the router
  /// must not bounce the user to `/tdlib-session` for those.
  bool get requiresAuthorizationFlow {
    if (!_auth.isAuthenticated) return false;
    switch (state.status) {
      case TdlibSessionStatus.authorizationRequired:
      case TdlibSessionStatus.waitCode:
      case TdlibSessionStatus.waitPassword:
      case TdlibSessionStatus.mismatch:
        return true;
      case TdlibSessionStatus.signedOut:
      case TdlibSessionStatus.checking:
      case TdlibSessionStatus.unavailable:
      case TdlibSessionStatus.ready:
      case TdlibSessionStatus.error:
        return false;
    }
  }

  TdlibAuthorizationRun? get activeRun => _activeRun;

  Future<void> authorizeAutomatically({
    required String phoneNumber,
    required int telegramUserId,
    required int backendUserId,
    required PendingTdlibMode mode,
    bool restartOtpWindow = false,
  }) async {
    final current = _autoTask;
    if (current != null && !restartOtpWindow) return current;
    _cancelAutomation(clearSecret: false);
    final runId = ++_autoRunId;
    final now = DateTime.now().toUtc();
    _activeRun = TdlibAuthorizationRun(
      runId: runId,
      backendUserId: backendUserId,
      telegramUserId: telegramUserId,
      phoneNumber: phoneNumber,
      nonce: _uuid.v4(),
      phoneSubmittedAt: now,
      mode: mode,
    );
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

  Future<void> retryOtp() async {
    final run = _activeRun;
    if (run == null) return;
    _cancelOtpTimer();
    final runId = ++_autoRunId;
    _activeRun = run.copyWith(runId: runId);
    if (state.status == TdlibSessionStatus.waitCode) {
      try {
        await _bridge.resendCode();
        _activeRun = _activeRun!.copyWith(
          phoneSubmittedAt: DateTime.now().toUtc(),
          nonce: _uuid.v4(),
        );
      } catch (err) {
        final message = '$err'.toLowerCase();
        if (message.contains('flood') || message.contains('rate')) {
          _showManualCodeRequired(
            error:
                'Telegram requires waiting before requesting another code. Enter the code manually if you already received one.',
          );
          return;
        }
        // Fall through with the existing nonce/startedAt — Telegram may still accept the old code.
      }
    } else {
      // No longer waiting for code: re-check authorization state and continue.
      await check(force: true);
    }
    final task = _advanceAutomaticAuthorization(runId);
    _autoTask = task;
    try {
      await task;
    } finally {
      if (identical(_autoTask, task)) _autoTask = null;
    }
  }

  Future<void> submitManualCodeForAutomation(String code) async {
    final run = _activeRun;
    if (run == null) return;
    _cancelOtpTimer();
    final runId = ++_autoRunId;
    _activeRun = run.copyWith(runId: runId);
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

  Future<void> submitManualPasswordForAutomation(String password) async {
    final run = _activeRun;
    if (run == null || password.isEmpty) return;
    final runId = ++_autoRunId;
    _activeRun = run.copyWith(runId: runId);
    _setAutoStage(TdlibAutoAuthStage.submittingPassword);
    try {
      await submitPassword(password);
    } catch (_) {
      _setAutoStage(
        TdlibAutoAuthStage.manualPasswordRequired,
        error: 'Telegram rejected that cloud password.',
      );
      return;
    }
    try {
      await _storage.saveTelegramCloudPassword(
        backendUserId: run.backendUserId,
        telegramUserId: run.telegramUserId,
        password: password,
      );
    } catch (_) {
      // Storage write failure should not abort authorization.
    }
    await _advanceAutomaticAuthorization(runId);
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

  void _handleAuthChanged() {
    if (!_auth.isAuthenticated) {
      _cancelAutomation(clearSecret: true);
    } else {
      final run = _activeRun;
      final activeBackendUserId = _auth.user?.userId;
      if (run != null &&
          activeBackendUserId != null &&
          activeBackendUserId != 0 &&
          activeBackendUserId != run.backendUserId) {
        _cancelAutomation(clearSecret: true);
      }
    }
    _authDebounce?.cancel();
    _authDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(check(force: true));
    });
  }

  void _emitChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    _cancelAutomation(clearSecret: true);
    _authDebounce?.cancel();
    super.dispose();
  }
}
