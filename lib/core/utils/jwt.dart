import 'dart:convert';

import '../../models/auth_user.dart';

AuthUser? decodeJwtUser(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is num && exp < DateTime.now().millisecondsSinceEpoch ~/ 1000)
      return null;
    final telegramId = payload['sub'];
    final firstName = payload['firstName'];
    if (telegramId == null || firstName == null) return null;
    return AuthUser(
      userId:
          (payload['userId'] as num?)?.toInt() ?? (telegramId as num).toInt(),
      telegramId: (telegramId as num).toInt(),
      firstName: '$firstName',
      lastName: payload['lastName'] as String?,
      username: payload['username'] as String?,
    );
  } catch (_) {
    return null;
  }
}
