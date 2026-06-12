import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../models/account_vault.dart';
import '../../../models/auth_user.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/social_icons.dart';
import '../../../widgets/sheet/sheet_drag_handle.dart';
import '../../auth/auth_controller.dart';
import '../app_settings_controller.dart';
import '../gallery_backup_controller.dart';
import '../storage_summary_controller.dart';
import 'switch_account_provider.dart';

part 'account_bottom_sheet/account_sheet_actions.dart';
part 'account_bottom_sheet/account_sheet_cards.dart';
part 'account_bottom_sheet/account_sheet_identity.dart';
part 'account_bottom_sheet/account_sheet_switcher.dart';
part 'account_bottom_sheet/account_sheet_tdlib_chip.dart';

class AccountBottomSheet extends ConsumerStatefulWidget {
  const AccountBottomSheet({super.key});

  @override
  ConsumerState<AccountBottomSheet> createState() => _AccountBottomSheetState();
}

class _CompactPillAction {
  const _CompactPillAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _AccountBottomSheetState extends ConsumerState<AccountBottomSheet>
    with SingleTickerProviderStateMixin {
  static const _sectionRadius = 28.0;
  static const _sectionSpacing = 14.0;
  static const _sheetHorizontalPadding = AppSpacing.lg;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      unawaited(auth.refreshProfile());
      unawaited(auth.refreshSavedAccountSnapshots());
      ref.read(storageSummaryControllerProvider).ensureLoaded();
    });
  }

  void _toggleSwitchAccountCard() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  Future<void> _openTelegramProfile(
    BuildContext context,
    String? username,
  ) async {
    final name = username?.trim();
    final uri = Uri.parse(
      name == null || name.isEmpty ? 'https://t.me' : 'https://t.me/$name',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final summary =
        ref.watch(storageSummaryControllerProvider).value ??
        StorageSummary.empty;
    final backupOn = ref
        .watch(appSettingsControllerProvider)
        .state
        .galleryBackupEnabled;
    final user = auth.user;

    final activeAccount = _activeAccountSnapshot(auth.activeAccount, user);

    final switchState = ref.watch(switchAccountProvider);
    final otherAccounts = activeAccount == null
        ? <SavedAccount>[]
        : switchState.accounts
              .where((a) => a.userId != activeAccount.userId)
              .toList();

    final accountLabel =
        activeAccount?.username != null && activeAccount!.username!.isNotEmpty
        ? '@${activeAccount.username}'
        : 'ID ${activeAccount?.telegramId ?? 0}';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetDragHandle(),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _sheetHorizontalPadding,
                  ),
                  child: Column(
                    children: [
                      if (activeAccount != null)
                        _buildAccountIdentity(
                          context,
                          activeAccount,
                          accountLabel,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      if (activeAccount != null)
                        _buildSwitchAccountCard(
                          context,
                          activeAccount,
                          otherAccounts,
                        ),
                      const SizedBox(height: _sectionSpacing),
                      _buildBackupCard(context, backupOn),
                      const SizedBox(height: _sectionSpacing),
                      _buildStorageCard(context, summary),
                      const SizedBox(height: _sectionSpacing),
                      _buildCompactActionPill(
                        context,
                        actions: [
                          _CompactPillAction(
                            icon: Icons.image_outlined,
                            label: 'Free up backed-up media',
                            onTap: () {
                              context.safePush('/profile/free-up-space');
                            },
                          ),
                          _CompactPillAction(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onTap: () {
                              context.safePush('/settings');
                            },
                          ),
                          _CompactPillAction(
                            icon: Icons.bar_chart_rounded,
                            label: 'My Data in Telegram Drive',
                            onTap: () {
                              context.safePush('/profile/my-data');
                            },
                          ),
                          _CompactPillAction(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & Feedback',
                            onTap: () {
                              _showHelpFeedbackDialog(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

SavedAccount? _activeAccountSnapshot(SavedAccount? saved, AuthUser? user) {
  if (user == null) return saved;
  final now = DateTime.now();
  return SavedAccount(
    userId: user.userId,
    telegramId: user.telegramId != 0 ? user.telegramId : saved?.telegramId ?? 0,
    firstName: user.firstName,
    lastName: user.lastName,
    username: user.username,
    phoneNumber: saved?.phoneNumber,
    photoUrl: user.photoUrl,
    localPhotoPath: saved?.localPhotoPath,
    token: saved?.token ?? '',
    addedAt: saved?.addedAt ?? now,
    lastUsedAt: saved?.lastUsedAt ?? now,
    tokenStatus: saved?.tokenStatus ?? TokenStatus.valid,
    sessionStatus: saved?.sessionStatus,
    requiresReconnect: saved?.requiresReconnect ?? false,
  );
}

/// Background for the account sheet itself. Public so the
/// `showModalBottomSheet` call site can paint the sheet's own Material —
/// in dark mode the sheet sits near-black while the cards float lighter.
Color accountSheetBackgroundColor(ColorScheme scheme) {
  return scheme.brightness == Brightness.dark
      ? scheme.surfaceContainerLowest
      : scheme.surfaceContainerLow;
}

Color _profileSectionColor(ColorScheme scheme) {
  if (scheme.brightness == Brightness.dark) {
    // Tonal surface (not a flat white overlay) so the cards carry the
    // theme's tint and stay visibly lighter than the near-black sheet.
    return scheme.surfaceContainerHigh;
  }

  return Color.alphaBlend(
    scheme.onSurface.withValues(alpha: 0.035),
    scheme.surfaceContainerLow,
  );
}

Color _profileSectionDividerColor(ColorScheme scheme) {
  return scheme.outlineVariant.withValues(
    alpha: scheme.brightness == Brightness.dark ? 0.18 : 0.42,
  );
}

class _ProfileSheetSection extends StatelessWidget {
  const _ProfileSheetSection({required this.child, this.borderRadius});

  final Widget child;

  /// Per-corner override so segmented groups can round only their outer
  /// edges; falls back to the uniform section radius.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: _profileSectionColor(scheme),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            borderRadius ??
            BorderRadius.circular(_AccountBottomSheetState._sectionRadius),
        side: scheme.brightness == Brightness.light
            ? BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      child: child,
    );
  }
}
