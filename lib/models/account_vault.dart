import 'auth_user.dart';

const int kMaxSavedAccounts = 5;

enum TokenStatus {
  valid,
  expired,
  needsLogin;

  static TokenStatus fromJson(Object? value) {
    return TokenStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TokenStatus.valid,
    );
  }
}

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

  AuthUser toAuthUser() => AuthUser(
    userId: userId,
    telegramId: telegramId,
    firstName: firstName,
    lastName: lastName,
    username: username,
    photoUrl: localPhotoPath ?? photoUrl,
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
}

class AccountVault {
  const AccountVault({
    required this.accounts,
    required this.activeUserId,
    this.maxSavedAccounts = kMaxSavedAccounts,
  });

  const AccountVault.empty()
    : accounts = const [],
      activeUserId = null,
      maxSavedAccounts = kMaxSavedAccounts;

  final List<SavedAccount> accounts;
  final int? activeUserId;
  final int maxSavedAccounts;

  SavedAccount? get activeAccount {
    final id = activeUserId;
    if (id == null) return null;
    for (final account in accounts) {
      if (account.userId == id) return account;
    }
    return null;
  }

  bool get isFull => accounts.length >= maxSavedAccounts;

  AccountVault copyWith({
    List<SavedAccount>? accounts,
    int? activeUserId,
    int? maxSavedAccounts,
    bool clearActiveUserId = false,
  }) {
    return AccountVault(
      accounts: accounts ?? this.accounts,
      activeUserId: clearActiveUserId
          ? null
          : (activeUserId ?? this.activeUserId),
      maxSavedAccounts: maxSavedAccounts ?? this.maxSavedAccounts,
    );
  }

  AccountVault upsert(SavedAccount account, {bool makeActive = false}) {
    final updated = <SavedAccount>[];
    var replaced = false;
    for (final existing in accounts) {
      final sameUser = existing.userId == account.userId;
      final sameTelegram =
          account.telegramId != 0 && existing.telegramId == account.telegramId;
      if (sameUser || sameTelegram) {
        updated.add(account.copyWith(addedAt: existing.addedAt));
        replaced = true;
      } else {
        updated.add(existing);
      }
    }
    if (!replaced) updated.add(account);
    return copyWith(
      accounts: updated,
      activeUserId: makeActive ? account.userId : activeUserId,
    );
  }

  AccountVault remove(int userId) {
    final updated = accounts
        .where((account) => account.userId != userId)
        .toList();
    return copyWith(
      accounts: updated,
      clearActiveUserId: activeUserId == userId,
    );
  }

  AccountVault markTokenStatus(int userId, TokenStatus status) {
    return copyWith(
      accounts: accounts
          .map(
            (account) => account.userId == userId
                ? account.copyWith(tokenStatus: status)
                : account,
          )
          .toList(),
    );
  }

  AccountVault touchActive(int userId, DateTime at) {
    return copyWith(
      activeUserId: userId,
      accounts: accounts
          .map(
            (account) => account.userId == userId
                ? account.copyWith(
                    lastUsedAt: at,
                    tokenStatus: TokenStatus.valid,
                  )
                : account,
          )
          .toList(),
    );
  }

  List<SavedAccount> validAccountsByRecent() {
    final valid = accounts.where((account) => account.hasUsableToken).toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return valid;
  }

  Map<String, dynamic> toJson() => {
    'accounts': accounts.map((account) => account.toJson()).toList(),
    'activeUserId': activeUserId,
    'maxSavedAccounts': maxSavedAccounts,
  };

  factory AccountVault.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    final accounts = rawAccounts is List
        ? rawAccounts
              .whereType<Map>()
              .map(
                (item) =>
                    SavedAccount.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((account) => account.token.isNotEmpty)
              .toList()
        : <SavedAccount>[];
    final active = json['activeUserId'] ?? json['active_user_id'];
    return AccountVault(
      accounts: accounts,
      activeUserId: active is num ? active.toInt() : int.tryParse('$active'),
      maxSavedAccounts:
          (json['maxSavedAccounts'] as num?)?.toInt() ?? kMaxSavedAccounts,
    );
  }
}
