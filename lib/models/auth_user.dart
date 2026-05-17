class AuthUser {
  const AuthUser({
    required this.userId,
    required this.telegramId,
    required this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
  });

  final int userId;
  final int telegramId;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;

  String get displayName => [
    firstName,
    lastName,
  ].whereType<String>().where((v) => v.isNotEmpty).join(' ');

  AuthUser copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? photoUrl,
  }) {
    return AuthUser(
      userId: userId,
      telegramId: telegramId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': userId,
    'telegramId': telegramId,
    'firstName': firstName,
    'lastName': lastName,
    'username': username,
    'photoUrl': photoUrl,
  };

  factory AuthUser.fromMeJson(Map<String, dynamic> json) {
    final payload = _profilePayload(json);
    final id = payload['id'] ?? payload['userId'] ?? payload['user_id'];
    final telegramId =
        payload['telegramId'] ??
        payload['telegram_id'] ??
        payload['telegramUserId'] ??
        payload['telegram_user_id'];
    return AuthUser(
      userId: id is num ? id.toInt() : int.parse('$id'),
      telegramId: telegramId is num
          ? telegramId.toInt()
          : int.tryParse('${telegramId ?? ''}') ?? 0,
      firstName: _stringValue(payload, const ['firstName', 'first_name']) ?? '',
      lastName: _stringValue(payload, const ['lastName', 'last_name']),
      username: _stringValue(payload, const ['username']),
      photoUrl: _photoUrl(payload),
    );
  }

  factory AuthUser.fromJwtPayload(Map<String, dynamic> payload) {
    final telegramId =
        payload['sub'] ??
        payload['telegramId'] ??
        payload['telegram_id'] ??
        payload['telegramUserId'] ??
        payload['telegram_user_id'];
    final userId = payload['userId'] ?? payload['user_id'] ?? telegramId;
    final firstName = _stringValue(payload, const ['firstName', 'first_name']);
    if (telegramId == null || firstName == null) {
      throw const FormatException('JWT user payload is incomplete.');
    }
    return AuthUser(
      userId: userId is num ? userId.toInt() : int.parse('$userId'),
      telegramId: telegramId is num
          ? telegramId.toInt()
          : int.parse('$telegramId'),
      firstName: firstName,
      lastName: _stringValue(payload, const ['lastName', 'last_name']),
      username: _stringValue(payload, const ['username']),
      photoUrl: _photoUrl(payload),
    );
  }

  factory AuthUser.fromMe(Map<String, dynamic> json, AuthUser previous) {
    final payload = _profilePayload(json);
    return previous.copyWith(
      firstName: _stringValue(payload, const ['firstName', 'first_name']),
      lastName: _stringValue(payload, const ['lastName', 'last_name']),
      username: _stringValue(payload, const ['username']),
      photoUrl: _photoUrl(payload),
    );
  }

  static Map<String, dynamic> _profilePayload(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is Map) return Map<String, dynamic>.from(user);
    final profile = json['profile'];
    if (profile is Map) return Map<String, dynamic>.from(profile);
    return json;
  }

  static String? _stringValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _photoUrl(Map<String, dynamic> json) {
    final direct = _stringValue(json, const [
      'photoUrl',
      'photo_url',
      'profilePhotoUrl',
      'profile_photo_url',
      'avatarUrl',
      'avatar_url',
      'avatar',
    ]);
    if (direct != null) return direct;

    final photo =
        json['photo'] ?? json['profilePhoto'] ?? json['profile_photo'];
    if (photo is String && photo.trim().isNotEmpty) return photo.trim();
    if (photo is Map) {
      return _stringValue(Map<String, dynamic>.from(photo), const [
        'url',
        'photoUrl',
        'photo_url',
        'big',
        'small',
      ]);
    }
    return null;
  }
}
