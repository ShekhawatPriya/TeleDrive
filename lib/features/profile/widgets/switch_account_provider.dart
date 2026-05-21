import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../models/auth_user.dart';
import '../../auth/auth_controller.dart';
import '../cache_controller.dart';

class TelegramAccount {
  final int userId;
  final int telegramId;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;
  final bool isMock;

  const TelegramAccount({
    required this.userId,
    required this.telegramId,
    required this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
    this.isMock = false,
  });

  String get displayName => [
        firstName,
        lastName,
      ].whereType<String>().where((v) => v.isNotEmpty).join(' ');

  factory TelegramAccount.fromAuthUser(AuthUser user) {
    return TelegramAccount(
      userId: user.userId,
      telegramId: user.telegramId,
      firstName: user.firstName,
      lastName: user.lastName,
      username: user.username,
      photoUrl: user.photoUrl,
      isMock: false,
    );
  }
}

class SwitchAccountState {
  final List<TelegramAccount> accounts;
  final bool isRemoveMode;

  const SwitchAccountState({
    required this.accounts,
    required this.isRemoveMode,
  });

  SwitchAccountState copyWith({
    List<TelegramAccount>? accounts,
    bool? isRemoveMode,
  }) {
    return SwitchAccountState(
      accounts: accounts ?? this.accounts,
      isRemoveMode: isRemoveMode ?? this.isRemoveMode,
    );
  }
}

class SwitchAccountNotifier extends StateNotifier<SwitchAccountState> {
  final Ref _ref;

  SwitchAccountNotifier(this._ref)
      : super(const SwitchAccountState(
          accounts: [],
          isRemoveMode: false,
        )) {
    _init();
  }

  void _init() {
    final auth = _ref.read(authControllerProvider);
    final user = auth.user;

    final list = <TelegramAccount>[];
    if (user != null) {
      list.add(TelegramAccount.fromAuthUser(user));
    }

    // Add high-fidelity mock Telegram accounts matching Google Photos screenshot style
    list.addAll([
      const TelegramAccount(
        userId: 10001,
        telegramId: 58291048,
        firstName: 'Sreejan',
        lastName: 'Anand',
        username: 'sreejan_anand',
        photoUrl: null,
        isMock: true,
      ),
      const TelegramAccount(
        userId: 10002,
        telegramId: 92837194,
        firstName: 'Parmanand',
        lastName: 'Prasad',
        username: 'ao_pprasad',
        photoUrl: null,
        isMock: true,
      ),
      const TelegramAccount(
        userId: 10003,
        telegramId: 10928374,
        firstName: 'Gaming ID [14]',
        lastName: '',
        username: 'halkatcall14',
        photoUrl: null,
        isMock: true,
      ),
      const TelegramAccount(
        userId: 10004,
        telegramId: 48291038,
        firstName: 'Devs Do Code',
        lastName: '',
        username: 'devsdocode_work',
        photoUrl: null,
        isMock: true,
      ),
    ]);

    state = SwitchAccountState(
      accounts: list,
      isRemoveMode: false,
    );
  }

  void toggleRemoveMode() {
    state = state.copyWith(isRemoveMode: !state.isRemoveMode);
  }

  void setRemoveMode(bool isRemove) {
    state = state.copyWith(isRemoveMode: isRemove);
  }

  Future<void> removeAccount(BuildContext context, TelegramAccount account) async {
    if (account.isMock) {
      // For mock accounts, just remove them from the list instantly
      final updated = state.accounts.where((a) => a.userId != account.userId).toList();
      state = state.copyWith(accounts: updated);
    } else {
      // For the active account, perform a full local sign-out / wipe
      try {
        await _ref.read(cacheControllerProvider).clearCache();
        await _ref.read(authControllerProvider).logout();
      } catch (e) {
        debugPrint('Error during sign-out from switch account: $e');
      }
    }
  }

  void switchActiveAccount(TelegramAccount account) {
    // If we click an already active account, do nothing
    if (!account.isMock) return;

    // Simulate switching active accounts: we swap the mock account status
    // and make this new account active visually.
    final currentList = state.accounts;
    final activeIndex = currentList.indexWhere((a) => !a.isMock);
    final selectedIndex = currentList.indexWhere((a) => a.userId == account.userId);

    if (activeIndex != -1 && selectedIndex != -1) {
      final oldActive = currentList[activeIndex];
      final newActive = currentList[selectedIndex];

      final updated = List<TelegramAccount>.from(currentList);
      updated[activeIndex] = TelegramAccount(
        userId: oldActive.userId,
        telegramId: oldActive.telegramId,
        firstName: oldActive.firstName,
        lastName: oldActive.lastName,
        username: oldActive.username,
        photoUrl: oldActive.photoUrl,
        isMock: true,
      );

      updated[selectedIndex] = TelegramAccount(
        userId: newActive.userId,
        telegramId: newActive.telegramId,
        firstName: newActive.firstName,
        lastName: newActive.lastName,
        username: newActive.username,
        photoUrl: newActive.photoUrl,
        isMock: false,
      );

      state = state.copyWith(accounts: updated);
    }
  }
}

final switchAccountProvider = StateNotifierProvider<SwitchAccountNotifier, SwitchAccountState>((ref) {
  return SwitchAccountNotifier(ref);
});

// A simple backup status provider to keep track of the backup state
final mediaBackupProvider = StateProvider<bool>((ref) => false);
