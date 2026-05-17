import 'dart:convert';

import '../../models/auth_user.dart';

bool isJwtExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is! num) return false;
    return exp < DateTime.now().millisecondsSinceEpoch ~/ 1000;
  } catch (_) {
    return true;
  }
}

AuthUser? decodeJwtUser(String token) {
  try {
    final payload = decodeJwtPayload(token);
    if (payload == null) return null;
    if (isJwtExpired(token)) return null;
    return AuthUser.fromJwtPayload(payload);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    return payload;
  } catch (_) {
    return null;
  }
}
