import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../../drive/drive_controller.dart';
import '../../../models/drive_models.dart';
import '../app_settings_controller.dart';
import '../gallery_backup_controller.dart';
import 'switch_account_provider.dart';

part 'account_bottom_sheet/account_sheet_actions.dart';
part 'account_bottom_sheet/account_sheet_cards.dart';
part 'account_bottom_sheet/account_sheet_identity.dart';
part 'account_bottom_sheet/account_sheet_switcher.dart';

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

  final Widget icon;
  final String label;
  final VoidCallback onTap;
}

class _AccountBottomSheetState extends ConsumerState<AccountBottomSheet>
    with SingleTickerProviderStateMixin {
  static const _sectionRadius = 32.0;
  static const _sectionSpacing = 14.0;
  static const _sheetHorizontalPadding = AppSpacing.lg;
  static const _compactActionRowHeight = 68.0;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      unawaited(auth.refreshProfile());
      unawaited(auth.refreshSavedAccountSnapshots());
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
    final drive = ref.watch(driveControllerProvider);
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
                      _buildStorageCard(
                        context,
                        drive.state.usedStorage,
                        drive.files,
                      ),
                      const SizedBox(height: _sectionSpacing),
                      _buildCompactActionPill(
                        context,
                        actions: [
                          _CompactPillAction(
                            icon: Image.asset(
                              'assets/icon/icons/broom.png',
                              width: 22,
                              height: 22,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            label: 'Free up backed-up media',
                            onTap: () {
                              context.safePush('/profile/free-up-space');
                            },
                          ),
                          _CompactPillAction(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            label: 'Settings',
                            onTap: () {
                              context.safePush('/settings');
                            },
                          ),
                          _CompactPillAction(
                            icon: SvgPicture.asset(
                              'assets/icon/icons/add_chart_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24.svg',
                              width: 22,
                              height: 22,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                                BlendMode.srcIn,
                              ),
                            ),
                            label: 'My Data in Telegram Drive',
                            onTap: () {
                              context.safePush('/profile/my-data');
                            },
                          ),
                          _CompactPillAction(
                            icon: Icon(
                              Icons.help_outline_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            label: 'Help & Feedback',
                            onTap: () {
                              _showHelpFeedbackDialog(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildLegalFooter(context),
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

Color _profileSectionColor(ColorScheme scheme) {
  if (scheme.brightness == Brightness.dark) {
    return Color.alphaBlend(
      Colors.black.withValues(alpha: 0.42),
      scheme.surfaceContainerLow,
    );
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
  const _ProfileSheetSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: _profileSectionColor(scheme),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _AccountBottomSheetState._sectionRadius,
        ),
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
