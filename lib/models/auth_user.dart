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

  factory AuthUser.fromMe(Map<String, dynamic> json, AuthUser previous) =>
      previous.copyWith(
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        username: json['username'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );
}
