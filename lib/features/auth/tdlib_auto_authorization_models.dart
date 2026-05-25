import 'package:flutter/foundation.dart';

enum TdlibAutoAuthStage {
  idle,
  checkingExistingSession,
  preparingEngine,
  submittingPhoneNumber,
  waitingForCode,
  submittingCode,
  waitingForPassword,
  submittingPassword,
  verifyingAccount,
  authorized,
  manualCodeRequired,
  manualPasswordRequired,
  failed,
}

enum TdlibCodeResolveStatus {
  pending,
  found,
  expired,
  manualRequired,
  wrongAccount,
  rateLimited,
  error;

  static TdlibCodeResolveStatus fromJson(Object? value) {
    return switch ('$value') {
      'found' => TdlibCodeResolveStatus.found,
      'expired' => TdlibCodeResolveStatus.expired,
      'manual_required' => TdlibCodeResolveStatus.manualRequired,
      'wrong_account' => TdlibCodeResolveStatus.wrongAccount,
      'rate_limited' => TdlibCodeResolveStatus.rateLimited,
      'error' => TdlibCodeResolveStatus.error,
      _ => TdlibCodeResolveStatus.pending,
    };
  }
}

@immutable
class TdlibCodeResolveResult {
  const TdlibCodeResolveResult({required this.status, this.code, this.message});

  final TdlibCodeResolveStatus status;
  final String? code;
  final String? message;

  factory TdlibCodeResolveResult.fromJson(Map<String, dynamic> json) {
    return TdlibCodeResolveResult(
      status: TdlibCodeResolveStatus.fromJson(json['status']),
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }
}

@immutable
class TdlibAutoAuthorizationState {
  const TdlibAutoAuthorizationState({
    this.stage = TdlibAutoAuthStage.idle,
    this.progressPercent = 0,
    this.otpSecondsRemaining,
    this.title = 'Authorize TDLib',
    this.subtitle = 'Setting up secure local transfer on this device.',
    this.error,
    this.canRetryAutomation = false,
    this.canEnterCodeManually = false,
    this.canEnterPasswordManually = false,
  });

  final TdlibAutoAuthStage stage;
  final int progressPercent;
  final int? otpSecondsRemaining;
  final String title;
  final String subtitle;
  final String? error;
  final bool canRetryAutomation;
  final bool canEnterCodeManually;
  final bool canEnterPasswordManually;

  bool get isAutomationActive =>
      stage == TdlibAutoAuthStage.checkingExistingSession ||
      stage == TdlibAutoAuthStage.preparingEngine ||
      stage == TdlibAutoAuthStage.submittingPhoneNumber ||
      stage == TdlibAutoAuthStage.waitingForCode ||
      stage == TdlibAutoAuthStage.submittingCode ||
      stage == TdlibAutoAuthStage.waitingForPassword ||
      stage == TdlibAutoAuthStage.submittingPassword ||
      stage == TdlibAutoAuthStage.verifyingAccount;

  TdlibAutoAuthorizationState copyWith({
    TdlibAutoAuthStage? stage,
    int? progressPercent,
    int? otpSecondsRemaining,
    bool clearOtpSecondsRemaining = false,
    String? title,
    String? subtitle,
    String? error,
    bool clearError = false,
    bool? canRetryAutomation,
    bool? canEnterCodeManually,
    bool? canEnterPasswordManually,
  }) {
    return TdlibAutoAuthorizationState(
      stage: stage ?? this.stage,
      progressPercent: progressPercent ?? this.progressPercent,
      otpSecondsRemaining: clearOtpSecondsRemaining
          ? null
          : otpSecondsRemaining ?? this.otpSecondsRemaining,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      error: clearError ? null : error ?? this.error,
      canRetryAutomation: canRetryAutomation ?? this.canRetryAutomation,
      canEnterCodeManually: canEnterCodeManually ?? this.canEnterCodeManually,
      canEnterPasswordManually:
          canEnterPasswordManually ?? this.canEnterPasswordManually,
    );
  }
}
