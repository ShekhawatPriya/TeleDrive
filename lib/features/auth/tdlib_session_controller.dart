import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/config/app_config.dart';
import '../../core/telegram/telegram_auth_bridge.dart';
import '../../core/telegram/telegram_client_exceptions.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import 'auth_controller.dart';

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
  });

  final TdlibSessionStatus status;
  final String? message;
  final String? authorizationState;
  final int? localTelegramUserId;

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
  }) {
    return TdlibSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      authorizationState: authorizationState ?? this.authorizationState,
      localTelegramUserId: localTelegramUserId ?? this.localTelegramUserId,
    );
  }
}

final tdlibSessionControllerProvider =
    ChangeNotifierProvider<TdlibSessionController>((ref) {
      final controller = TdlibSessionController(
        auth: ref.read(authControllerProvider),
        telegram: ref.read(telegramTransferServiceProvider),
      );
      ref.onDispose(controller.dispose);
      unawaited(controller.check());
      return controller;
    });

class TdlibSessionController extends ChangeNotifier {
  TdlibSessionController({
    required AuthController auth,
    required TelegramTransferService telegram,
    TelegramAuthBridge? bridge,
  }) : _auth = auth,
       _telegram = telegram,
       _bridge = bridge ?? TelegramAuthBridge() {
    _auth.addListener(_handleAuthChanged);
  }

  final AuthController _auth;
  final TelegramTransferService _telegram;
  final TelegramAuthBridge _bridge;
  TdlibSessionState state = const TdlibSessionState();
  Future<void>? _checking;
  Timer? _authDebounce;

  bool get isReadyForActiveUser =>
      !_auth.isAuthenticated || state.status == TdlibSessionStatus.ready;

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
    _authDebounce?.cancel();
    _authDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(check(force: true));
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    _authDebounce?.cancel();
    super.dispose();
  }
}
