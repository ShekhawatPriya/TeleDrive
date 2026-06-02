import 'auth_user.dart';

part 'account_vault_saved_account.dart';

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
    return accountByUserId(id);
  }

  SavedAccount? accountByUserId(int userId) {
    for (final account in accounts) {
      if (account.userId == userId) return account;
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
        if (!replaced) {
          updated.add(account.copyWith(addedAt: existing.addedAt));
        }
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
