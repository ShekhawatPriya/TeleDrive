import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_test/flutter_test.dart';

SavedAccount account({
  required int userId,
  required int telegramId,
  required String token,
  DateTime? addedAt,
  DateTime? lastUsedAt,
  TokenStatus tokenStatus = TokenStatus.valid,
}) {
  final now = DateTime(2026, 5, 22, 12);
  return SavedAccount(
    userId: userId,
    telegramId: telegramId,
    firstName: 'User $userId',
    token: token,
    addedAt: addedAt ?? now,
    lastUsedAt: lastUsedAt ?? now,
    tokenStatus: tokenStatus,
  );
}

void main() {
  test('upsert deduplicates by user id and preserves addedAt', () {
    final originalAddedAt = DateTime(2026, 1, 1);
    final vault = const AccountVault.empty().upsert(
      account(
        userId: 1,
        telegramId: 10,
        token: 'old',
        addedAt: originalAddedAt,
      ),
      makeActive: true,
    );

    final updated = vault.upsert(
      account(userId: 1, telegramId: 10, token: 'new'),
      makeActive: true,
    );

    expect(updated.accounts, hasLength(1));
    expect(updated.accounts.single.token, 'new');
    expect(updated.accounts.single.addedAt, originalAddedAt);
    expect(updated.activeUserId, 1);
  });

  test('upsert deduplicates by telegram id', () {
    final vault = const AccountVault.empty()
        .upsert(account(userId: 1, telegramId: 10, token: 'old'))
        .upsert(account(userId: 2, telegramId: 10, token: 'new'));

    expect(vault.accounts, hasLength(1));
    expect(vault.accounts.single.userId, 2);
    expect(vault.accounts.single.token, 'new');
  });

  test('validAccountsByRecent excludes expired and needs-login accounts', () {
    final vault = const AccountVault.empty()
        .upsert(
          account(
            userId: 1,
            telegramId: 10,
            token: 'one',
            lastUsedAt: DateTime(2026, 5, 20),
          ),
        )
        .upsert(
          account(
            userId: 2,
            telegramId: 20,
            token: 'two',
            lastUsedAt: DateTime(2026, 5, 22),
          ),
        )
        .upsert(
          account(
            userId: 3,
            telegramId: 30,
            token: 'three',
            tokenStatus: TokenStatus.needsLogin,
          ),
        )
        .markTokenStatus(1, TokenStatus.expired);

    final valid = vault.validAccountsByRecent();

    expect(valid.map((item) => item.userId), [2]);
  });

  test('remove clears active user only when removing active account', () {
    final vault = const AccountVault.empty()
        .upsert(
          account(userId: 1, telegramId: 10, token: 'one'),
          makeActive: true,
        )
        .upsert(account(userId: 2, telegramId: 20, token: 'two'));

    expect(vault.remove(2).activeUserId, 1);
    expect(vault.remove(1).activeUserId, isNull);
  });

  test('serializes local profile photo path', () {
    final saved = account(userId: 1, telegramId: 10, token: 'one').copyWith(
      photoUrl: 'https://example.test/photo.jpg?token=secret',
      localPhotoPath: '/data/user/0/app/profile_photos/1.jpg',
    );

    final parsed = SavedAccount.fromJson(saved.toJson());

    expect(parsed.photoUrl, saved.photoUrl);
    expect(parsed.localPhotoPath, saved.localPhotoPath);
    expect(parsed.toAuthUser().photoUrl, saved.photoUrl);
  });

  test('remote profile photo takes priority over local cache', () {
    final saved = account(userId: 1, telegramId: 10, token: 'one').copyWith(
      photoUrl: 'https://example.test/users/1/photo.jpg',
      localPhotoPath: '/data/user/0/app/profile_photos/1_10_123.jpg',
    );

    expect(saved.resolvedPhotoUrl, saved.photoUrl);
    expect(saved.toAuthUser().photoUrl, saved.photoUrl);
  });

  test(
    'valid local profile photo path is used when remote photo is missing',
    () {
      final saved = account(userId: 1, telegramId: 10, token: 'one').copyWith(
        localPhotoPath: '/data/user/0/app/profile_photos/1_10_123.jpg',
      );

      expect(saved.resolvedPhotoUrl, saved.localPhotoPath);
      expect(saved.toAuthUser().photoUrl, saved.localPhotoPath);
    },
  );

  test('mismatched local profile photo path falls back to remote photo', () {
    final saved = account(userId: 1, telegramId: 10, token: 'one').copyWith(
      photoUrl: 'https://example.test/users/1/photo.jpg',
      localPhotoPath: '/data/user/0/app/profile_photos/2_20_123.jpg',
    );

    expect(saved.resolvedPhotoUrl, saved.photoUrl);
    expect(saved.toAuthUser().photoUrl, saved.photoUrl);
  });

  test('accountByUserId returns exact match independent of list order', () {
    final first = account(userId: 1, telegramId: 10, token: 'one');
    final second = account(userId: 2, telegramId: 20, token: 'two');
    final vault = AccountVault(
      accounts: [second, first],
      activeUserId: first.userId,
    );

    expect(vault.accountByUserId(1), same(first));
    expect(vault.accountByUserId(2), same(second));
    expect(vault.accountByUserId(3), isNull);
  });
}
