import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/safe_navigation.dart';
import '../../../models/account_vault.dart';
import '../../../widgets/premium_toast.dart';
import '../../auth/auth_controller.dart';
import '../../drive/drive_controller.dart';
import '../../drive/drive_tab_commands.dart';
import '../../search/search_controller.dart';
import '../../share/share_controller.dart';
import '../../upload/upload_controller.dart';

class SwitchAccountState {
  final List<SavedAccount> accounts;
  final int? activeUserId;
  final bool isRemoveMode;
  final int? busyUserId;

  const SwitchAccountState({
    required this.accounts,
    required this.activeUserId,
    required this.isRemoveMode,
    this.busyUserId,
  });

  SwitchAccountState copyWith({
    List<SavedAccount>? accounts,
    int? activeUserId,
    bool? isRemoveMode,
    int? busyUserId,
    bool clearBusyUserId = false,
    bool clearActiveUserId = false,
  }) {
    return SwitchAccountState(
      accounts: accounts ?? this.accounts,
      activeUserId: clearActiveUserId
          ? null
          : (activeUserId ?? this.activeUserId),
      isRemoveMode: isRemoveMode ?? this.isRemoveMode,
      busyUserId: clearBusyUserId ? null : (busyUserId ?? this.busyUserId),
    );
  }
}

class SwitchAccountNotifier extends StateNotifier<SwitchAccountState> {
  SwitchAccountNotifier(this._ref)
    : super(
        const SwitchAccountState(
          accounts: [],
          activeUserId: null,
          isRemoveMode: false,
        ),
      ) {
    _syncFromAuth();
    _ref.listen<AuthController>(authControllerProvider, (_, __) {
      _syncFromAuth();
    });
  }

  final Ref _ref;

  void _syncFromAuth() {
    final auth = _ref.read(authControllerProvider);
    final activeId = auth.activeAccount?.userId;
    final accounts = [...auth.vault.accounts]
      ..sort((a, b) {
        if (a.userId == activeId) return -1;
        if (b.userId == activeId) return 1;
        return b.lastUsedAt.compareTo(a.lastUsedAt);
      });
    state = state.copyWith(
      accounts: accounts,
      activeUserId: activeId,
      clearActiveUserId: activeId == null,
    );
  }

  void toggleRemoveMode() {
    state = state.copyWith(isRemoveMode: !state.isRemoveMode);
  }

  void setRemoveMode(bool isRemove) {
    state = state.copyWith(isRemoveMode: isRemove);
  }

  Future<void> addAnotherAccount(BuildContext context) async {
    if (_uploadsBlocked(context)) return;
    final auth = _ref.read(authControllerProvider);
    if (auth.vault.accounts.length >= auth.vault.maxSavedAccounts) {
      showPremiumToast(
        context,
        title: 'Account limit reached',
        message:
            'You can keep up to ${auth.vault.maxSavedAccounts} accounts on this device.',
        icon: Icons.person_add_disabled_outlined,
      );
      return;
    }
    Navigator.of(context).maybePop();
    final returnTo = Uri.encodeComponent('/drive');
    context.safePush('/login?mode=addAccount&returnTo=$returnTo');
  }

  Future<void> reauthenticateAccount(
    BuildContext context,
    SavedAccount account,
  ) async {
    if (_uploadsBlocked(context)) return;
    Navigator.of(context).maybePop();
    final returnTo = Uri.encodeComponent('/drive');
    context.safePush(
      '/login?mode=reauthenticateAccount&targetUserId=${account.userId}&returnTo=$returnTo',
    );
  }

  Future<void> switchActiveAccount(
    BuildContext context,
    SavedAccount account,
  ) async {
    if (account.userId == state.activeUserId) return;
    if (_uploadsBlocked(context)) return;
    if (account.tokenStatus != TokenStatus.valid) {
      showPremiumToast(
        context,
        title: 'Session expired',
        message: 'Log in again to use ${account.displayName}.',
        icon: Icons.lock_clock_outlined,
      );
      await reauthenticateAccount(context, account);
      return;
    }

    state = state.copyWith(busyUserId: account.userId);
    try {
      await _ref.read(authControllerProvider).switchToAccount(account.userId);
      await _resetAccountScopedState();
      if (context.mounted) {
        Navigator.of(context).maybePop();
        context.go('/drive');
        showPremiumToast(
          context,
          title: 'Account switched',
          message: 'Now using ${account.displayName}.',
          icon: Icons.account_circle_outlined,
        );
      }
    } catch (err) {
      if (context.mounted) {
        showPremiumToast(
          context,
          title: 'Could not switch account',
          message: _ref
              .read(authRepositoryProvider)
              .api
              .errorMessage(err, 'Please try again.'),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      state = state.copyWith(clearBusyUserId: true);
    }
  }

  Future<void> removeAccount(BuildContext context, SavedAccount account) async {
    if (_uploadsBlocked(context)) return;
    final confirmed = await _confirmRemove(context, account);
    if (confirmed != true) return;

    final wasActive = account.userId == state.activeUserId;
    state = state.copyWith(busyUserId: account.userId);
    try {
      final stillAuthenticated = await _ref
          .read(authControllerProvider)
          .removeAccountFromDevice(account.userId);
      if (wasActive) {
        await _resetAccountScopedState();
      }
      if (context.mounted) {
        Navigator.of(context).maybePop();
        context.go(stillAuthenticated ? '/drive' : '/welcome');
        showPremiumToast(
          context,
          title: stillAuthenticated ? 'Account removed' : 'Signed out',
          message: stillAuthenticated
              ? 'Removed ${account.displayName} from this device.'
              : 'No saved accounts remain on this device.',
          icon: Icons.person_remove_outlined,
        );
      }
    } catch (err) {
      if (context.mounted) {
        showPremiumToast(
          context,
          title: 'Remove failed',
          message: _ref
              .read(authRepositoryProvider)
              .api
              .errorMessage(err, 'Please try again.'),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      state = state.copyWith(clearBusyUserId: true);
    }
  }

  bool _uploadsBlocked(BuildContext context) {
    final upload = _ref.read(uploadControllerProvider);
    if (!upload.hasBlockingUploads) return false;
    showPremiumToast(
      context,
      title: 'Uploads still running',
      message:
          'Please wait for current uploads to finish or cancel them before switching accounts.',
      icon: Icons.cloud_upload_outlined,
    );
    return true;
  }

  Future<void> _resetAccountScopedState() async {
    final upload = _ref.read(uploadControllerProvider);
    if (!upload.hasBlockingUploads) {
      upload.resetTerminalForAccountSwitch();
    }
    await _ref.read(driveControllerProvider).resetForAccountSwitch();
    final bootstrap = _ref
        .read(authControllerProvider)
        .takePendingDriveBootstrap();
    if (bootstrap != null) {
      _ref.read(driveControllerProvider).applyDriveState(bootstrap);
    } else {
      await _ref.read(driveControllerProvider).refresh(force: true);
    }
    _ref.read(shareControllerProvider).resetForAccountSwitch();
    _ref.read(selectionModeStateProvider).setDriveSelectMode(false);
    _ref.read(selectionModeStateProvider).setPhotosSelectMode(false);
    for (final scope in SearchScope.values) {
      _ref.read(searchQueryProvider(scope)).clear();
    }
  }

  Future<bool?> _confirmRemove(BuildContext context, SavedAccount account) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from this device?'),
        content: Text(
          'This removes ${account.displayName} from this phone only. Your cloud files and Telegram session are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

final switchAccountProvider =
    StateNotifierProvider<SwitchAccountNotifier, SwitchAccountState>((ref) {
      return SwitchAccountNotifier(ref);
    });

final mediaBackupProvider = StateProvider<bool>((ref) => false);
