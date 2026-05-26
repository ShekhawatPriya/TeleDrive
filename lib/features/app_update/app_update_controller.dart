import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import 'app_update_models.dart';
import 'app_update_service.dart';

class AppUpdateState {
  const AppUpdateState({
    this.update,
    this.isChecking = false,
    this.lastError,
    this.lastManualResultUpToDate = false,
    this.lastManualResultUpToDateVersion,
    this.promptToken = 0,
  });

  final AppUpdateInfo? update;
  final bool isChecking;
  final String? lastError;
  final bool lastManualResultUpToDate;
  final String? lastManualResultUpToDateVersion;
  final int promptToken;

  AppUpdateState copyWith({
    AppUpdateInfo? update,
    bool clearUpdate = false,
    bool? isChecking,
    String? lastError,
    bool clearLastError = false,
    bool? lastManualResultUpToDate,
    String? lastManualResultUpToDateVersion,
    bool clearManualUpToDate = false,
    int? promptToken,
  }) {
    return AppUpdateState(
      update: clearUpdate ? null : (update ?? this.update),
      isChecking: isChecking ?? this.isChecking,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastManualResultUpToDate: clearManualUpToDate
          ? false
          : (lastManualResultUpToDate ?? this.lastManualResultUpToDate),
      lastManualResultUpToDateVersion: clearManualUpToDate
          ? null
          : (lastManualResultUpToDateVersion ??
                this.lastManualResultUpToDateVersion),
      promptToken: promptToken ?? this.promptToken,
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService(),
);

final appUpdateControllerProvider =
    ChangeNotifierProvider<AppUpdateController>(
      (ref) => AppUpdateController(ref.watch(appUpdateServiceProvider)),
    );

class AppUpdateController extends ChangeNotifier {
  AppUpdateController(this._service);

  static const _kLastCheckMillis = 'app_update.last_check_millis';

  final AppUpdateService _service;
  Future<void>? _inFlight;

  AppUpdateState _state = const AppUpdateState();
  AppUpdateState get state => _state;

  Duration get _automaticInterval =>
      Duration(minutes: AppConfig.appUpdateCheckIntervalMinutes);

  void _set(AppUpdateState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> checkForUpdate({
    required AppUpdateCheckReason reason,
  }) async {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _runCheck(reason);
    _inFlight = future;
    try {
      await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _runCheck(AppUpdateCheckReason reason) async {
    final manual = reason == AppUpdateCheckReason.manual;

    if (reason == AppUpdateCheckReason.resume) {
      final prefs = await SharedPreferences.getInstance();
      final lastMillis = prefs.getInt(_kLastCheckMillis) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastMillis > 0 &&
          now - lastMillis < _automaticInterval.inMilliseconds) {
        return;
      }
    }

    if (manual) {
      _set(_state.copyWith(
        isChecking: true,
        clearLastError: true,
        clearManualUpToDate: true,
      ));
    }

    AppUpdateInfo? info;
    String? error;
    try {
      info = await _service.checkForUpdate();
    } on AppUpdateFetchException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Network error';
    }

    final prefs = await SharedPreferences.getInstance();
    if (error == null) {
      await prefs.setInt(
        _kLastCheckMillis,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    if (error != null) {
      if (manual) {
        _set(_state.copyWith(
          isChecking: false,
          lastError: error,
          clearManualUpToDate: true,
        ));
      }
      return;
    }

    if (info == null) {
      if (manual) {
        _set(_state.copyWith(
          isChecking: false,
          clearUpdate: true,
          clearLastError: true,
          lastManualResultUpToDate: true,
          promptToken: _state.promptToken + 1,
        ));
      } else {
        _set(_state.copyWith(clearUpdate: true));
      }
      return;
    }

    _set(_state.copyWith(
      update: info,
      isChecking: false,
      clearLastError: true,
      clearManualUpToDate: true,
      promptToken: _state.promptToken + 1,
    ));
  }

  Future<bool> openDownload() async {
    final current = _state.update;
    if (current == null) return false;
    final uri = Uri.tryParse(current.apkUrl);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void clearManualMessages() {
    _set(_state.copyWith(
      clearLastError: true,
      clearManualUpToDate: true,
    ));
  }
}
