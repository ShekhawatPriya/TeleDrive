import 'package:flutter/services.dart';

import 'telegram_client_exceptions.dart';

class TelegramAuthBridge {
  TelegramAuthBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('teledrive/tdlib');

  final MethodChannel _channel;

  Future<int?> getCurrentTelegramUserId() async {
    try {
      final result = await _channel.invokeMethod<Object?>('getMe');
      if (result is! Map) return null;
      return ((result['telegramUserId'] ?? result['id']) as num?)?.toInt();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (err) {
      if (err.code == 'tdlib_unavailable') return null;
      throw TelegramClientException(
        err.message ?? 'Could not read local Telegram account.',
        code: err.code,
      );
    }
  }

  Future<Map<String, dynamic>> health() => _invokeMap('health', {});

  Future<Map<String, dynamic>> setPhoneNumber(String phoneNumber) {
    return _invokeMap('setPhoneNumber', {'phoneNumber': phoneNumber});
  }

  Future<Map<String, dynamic>> checkCode(String code) {
    return _invokeMap('checkCode', {'code': code});
  }

  Future<Map<String, dynamic>> checkPassword(String password) {
    return _invokeMap('checkPassword', {'password': password});
  }

  Future<void> assertMatchesBackend(int backendTelegramUserId) async {
    final local = await getCurrentTelegramUserId();
    if (local == null) {
      throw const TelegramClientUnavailableException(
        'Connect Telegram on this device before using direct media transfer.',
        code: 'tdlib_not_connected',
      );
    }
    if (local != backendTelegramUserId) {
      throw TelegramAccountMismatchException(
        'Local Telegram account does not match this TeleDrive account.',
        code: 'tdlib_account_mismatch',
      );
    }
  }

  Future<Map<String, dynamic>> _invokeMap(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, args);
      if (result is Map) return Map<String, dynamic>.from(result);
      return <String, dynamic>{};
    } on MissingPluginException {
      throw const TelegramClientUnavailableException(
        'TDLib bridge is not installed.',
        code: 'tdlib_bridge_missing',
      );
    } on PlatformException catch (err) {
      if (err.code == 'tdlib_unavailable') {
        throw TelegramClientUnavailableException(
          err.message ?? 'TDLib is not available.',
          code: err.code,
        );
      }
      throw TelegramClientException(
        err.message ?? 'TDLib authentication failed.',
        code: err.code,
      );
    }
  }
}
