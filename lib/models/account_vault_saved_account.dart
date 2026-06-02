part of 'account_vault.dart';

class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.telegramId,
    required this.firstName,
    required this.token,
    required this.addedAt,
    required this.lastUsedAt,
    this.lastName,
    this.username,
    this.phoneNumber,
    this.photoUrl,
    this.localPhotoPath,
    this.tokenStatus = TokenStatus.valid,
    this.sessionStatus,
    this.requiresReconnect = false,
  });

  final int userId;
  final int telegramId;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? phoneNumber;
  final String? photoUrl;
  final String? localPhotoPath;
  final String token;
  final DateTime addedAt;
  final DateTime lastUsedAt;
  final TokenStatus tokenStatus;
  final String? sessionStatus;
  final bool requiresReconnect;

  String get displayName => [
    firstName,
    lastName,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');

  bool get hasUsableToken =>
      token.isNotEmpty && tokenStatus == TokenStatus.valid;

  String? get resolvedPhotoUrl {
    final remote = photoUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;

    final local = localPhotoPath?.trim();
    if (local != null &&
        local.isNotEmpty &&
        _localPhotoBelongsToAccount(local)) {
      return local;
    }
    return null;
  }

  AuthUser toAuthUser() => AuthUser(
    userId: userId,
    telegramId: telegramId,
    firstName: firstName,
    lastName: lastName,
    username: username,
    photoUrl: resolvedPhotoUrl,
  );

  SavedAccount copyWith({
    int? userId,
    int? telegramId,
    String? firstName,
    String? lastName,
    String? username,
    String? phoneNumber,
    String? photoUrl,
    String? localPhotoPath,
    String? token,
    DateTime? addedAt,
    DateTime? lastUsedAt,
    TokenStatus? tokenStatus,
    String? sessionStatus,
    bool? requiresReconnect,
    bool clearLastName = false,
    bool clearUsername = false,
    bool clearPhoneNumber = false,
    bool clearPhotoUrl = false,
    bool clearLocalPhotoPath = false,
    bool clearSessionStatus = false,
  }) {
    return SavedAccount(
      userId: userId ?? this.userId,
      telegramId: telegramId ?? this.telegramId,
      firstName: firstName ?? this.firstName,
      lastName: clearLastName ? null : (lastName ?? this.lastName),
      username: clearUsername ? null : (username ?? this.username),
      phoneNumber: clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      localPhotoPath: clearLocalPhotoPath
          ? null
          : (localPhotoPath ?? this.localPhotoPath),
      token: token ?? this.token,
      addedAt: addedAt ?? this.addedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      tokenStatus: tokenStatus ?? this.tokenStatus,
      sessionStatus: clearSessionStatus
          ? null
          : (sessionStatus ?? this.sessionStatus),
      requiresReconnect: requiresReconnect ?? this.requiresReconnect,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'telegramId': telegramId,
    'firstName': firstName,
    'lastName': lastName,
    'username': username,
    'phoneNumber': phoneNumber,
    'photoUrl': photoUrl,
    'localPhotoPath': localPhotoPath,
    'token': token,
    'addedAt': addedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'tokenStatus': tokenStatus.name,
    'sessionStatus': sessionStatus,
    'requiresReconnect': requiresReconnect,
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] ?? json['user_id'] ?? json['id'];
    final telegramId =
        json['telegramId'] ?? json['telegram_id'] ?? json['telegramUserId'];
    final now = DateTime.now();
    return SavedAccount(
      userId: userId is num ? userId.toInt() : int.parse('$userId'),
      telegramId: telegramId is num
          ? telegramId.toInt()
          : int.tryParse('${telegramId ?? ''}') ?? 0,
      firstName: '${json['firstName'] ?? json['first_name'] ?? ''}',
      lastName: _string(json['lastName'] ?? json['last_name']),
      username: _string(json['username']),
      phoneNumber: _string(json['phoneNumber'] ?? json['phone_number']),
      photoUrl: _string(json['photoUrl'] ?? json['photo_url']),
      localPhotoPath: _string(
        json['localPhotoPath'] ?? json['local_photo_path'],
      ),
      token: '${json['token'] ?? ''}',
      addedAt: DateTime.tryParse('${json['addedAt'] ?? ''}') ?? now,
      lastUsedAt: DateTime.tryParse('${json['lastUsedAt'] ?? ''}') ?? now,
      tokenStatus: TokenStatus.fromJson(json['tokenStatus']),
      sessionStatus: _string(json['sessionStatus']),
      requiresReconnect: json['requiresReconnect'] == true,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _localPhotoBelongsToAccount(String value) {
    final path = value.startsWith('file://')
        ? (Uri.tryParse(value)?.toFilePath() ?? value)
        : value;
    final parts = path.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty);
    final fileName = parts.isEmpty ? path : parts.last;
    return fileName == '$userId.jpg' || fileName.startsWith('${userId}_');
  }
}
