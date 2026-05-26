import 'package:flutter/foundation.dart';

import 'auth_controller.dart';
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

@immutable
class TdlibAuthorizationRun {
  const TdlibAuthorizationRun({
    required this.runId,
    required this.backendUserId,
    required this.telegramUserId,
    required this.phoneNumber,
    required this.nonce,
    required this.phoneSubmittedAt,
    required this.mode,
  });

  final int runId;
  final int backendUserId;
  final int telegramUserId;
  final String phoneNumber;
  final String nonce;
  final DateTime phoneSubmittedAt;
  final PendingTdlibMode mode;

  TdlibAuthorizationRun copyWith({
    int? runId,
    DateTime? phoneSubmittedAt,
    String? nonce,
  }) {
    return TdlibAuthorizationRun(
      runId: runId ?? this.runId,
      backendUserId: backendUserId,
      telegramUserId: telegramUserId,
      phoneNumber: phoneNumber,
      nonce: nonce ?? this.nonce,
      phoneSubmittedAt: phoneSubmittedAt ?? this.phoneSubmittedAt,
      mode: mode,
    );
  }
}
