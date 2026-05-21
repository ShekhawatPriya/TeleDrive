import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/github_icon.dart';
import '../../../widgets/sheet/sheet_drag_handle.dart';
import '../../auth/auth_controller.dart';
import '../../drive/drive_controller.dart';
import '../../../models/drive_models.dart';
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

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _AccountBottomSheetState extends ConsumerState<AccountBottomSheet>
    with SingleTickerProviderStateMixin {
  static const _sectionRadius = 32.0;
  static const _sectionSpacing = 14.0;
  static const _sheetHorizontalPadding = AppSpacing.lg;
  static const _compactActionRowHeight = 54.0;
  static const _compactActionDividerHeight = 3.0;

  bool _isExpanded = false;

  void _toggleSwitchAccountCard(SwitchAccountNotifier notifier) {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        notifier.setRemoveMode(false);
      }
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
    final switchState = ref.watch(switchAccountProvider);
    final backupOn = ref.watch(mediaBackupProvider);
    final user = auth.user;

    final activeAccount = switchState.accounts.firstWhere(
      (a) => !a.isMock,
      orElse: () => TelegramAccount(
        userId: user?.userId ?? 0,
        telegramId: user?.telegramId ?? 0,
        firstName: user?.firstName ?? 'Anonymous',
        lastName: user?.lastName,
        username: user?.username,
        photoUrl: user?.photoUrl,
        isMock: false,
      ),
    );

    final otherAccounts = switchState.accounts
        .where((a) => a.userId != activeAccount.userId)
        .toList();

    final accountLabel =
        activeAccount.username != null && activeAccount.username!.isNotEmpty
        ? '@${activeAccount.username}'
        : 'ID ${activeAccount.telegramId}';

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
                      _buildAccountIdentity(context, activeAccount, accountLabel),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSwitchAccountCard(
                        context,
                        activeAccount,
                        otherAccounts,
                      ),
                      const SizedBox(height: _sectionSpacing),
                      _buildBackupCard(context, backupOn),
                      const SizedBox(height: _sectionSpacing),
                      _buildStorageCard(context, drive.state.usedStorage, drive.files),
                      const SizedBox(height: _sectionSpacing),
                      _buildCompactActionPill(
                        context,
                        actions: [
                          _CompactPillAction(
                            icon: Icons.phonelink_erase_rounded,
                            label: 'Free up space on this device',
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
                            icon: Icons.analytics_outlined,
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
