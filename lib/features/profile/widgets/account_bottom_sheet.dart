import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../widgets/profile_avatar.dart';
import '../../auth/auth_controller.dart';
import 'switch_account_provider.dart';

class AccountBottomSheet extends ConsumerStatefulWidget {
  const AccountBottomSheet({super.key});

  @override
  ConsumerState<AccountBottomSheet> createState() => _AccountBottomSheetState();
}

class _AccountBottomSheetState extends ConsumerState<AccountBottomSheet> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  Future<void> _openTelegramProfile(BuildContext context, String? username) async {
    final name = username?.trim();
    final uri = Uri.parse(name == null || name.isEmpty ? 'https://t.me' : 'https://t.me/$name');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = ref.watch(authControllerProvider);
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

    final otherAccounts = switchState.accounts.where((a) => a.userId != activeAccount.userId).toList();

    final accountLabel = activeAccount.username != null && activeAccount.username!.isNotEmpty
        ? '@${activeAccount.username}'
        : 'ID ${activeAccount.telegramId}';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle (visual matching)
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Top Header: Centered account email/username & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  const SizedBox(width: 48), // Spacer to balance close button
                  Expanded(
                    child: Text(
                      accountLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Main sheet contents in a scrollable view
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      // Active Account Avatar with edit overlay
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: _buildAvatarWidget(activeAccount, size: 76),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _openTelegramProfile(context, activeAccount.username),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Display Name: Hi, Username!
                      Text(
                        'Hi, ${activeAccount.displayName}!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Manage Account deep-link button
                      OutlinedButton(
                        onPressed: () => _openTelegramProfile(context, activeAccount.username),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: scheme.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Manage Account',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Switch Account Card
                      _buildSwitchAccountCard(context, activeAccount, otherAccounts),
                      const SizedBox(height: AppSpacing.md),

                      // Backup Section
                      _buildBackupCard(context, backupOn),
                      const SizedBox(height: AppSpacing.md),

                      // Action Items list
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: scheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.lgR,
                        ),
                        child: Column(
                          children: [
                            _buildActionRow(
                              context,
                              icon: Icons.cloud_queue_rounded,
                              label: 'Storage',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.safePush('/profile');
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildActionRow(
                              context,
                              icon: Icons.analytics_outlined,
                              label: 'My Data in Telegram Drive',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Your Telegram Drive data is fully encrypted and synced.')),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildActionRow(
                              context,
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () {
                                Navigator.of(context).pop();
                                context.safePush('/settings');
                              },
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildActionRow(
                              context,
                              icon: Icons.help_outline_rounded,
                              label: 'Help & Feedback',
                              onTap: () {
                                _showHelpFeedbackDialog(context);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Footer with Privacy / Terms
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              context.safePush('/privacy');
                            },
                            child: Text(
                              'Privacy Policy',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '•',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              context.safePush('/terms');
                            },
                            child: Text(
                              'Terms of Service',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.underline,
                              ),
                            ),
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

  // Switch Account Card Builder
  Widget _buildSwitchAccountCard(
    BuildContext context,
    TelegramAccount activeAccount,
    List<TelegramAccount> otherAccounts,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final switchState = ref.watch(switchAccountProvider);
    final notifier = ref.read(switchAccountProvider.notifier);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of Switch Account card (Tappable for expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                // Turn off remove mode if collapsing
                if (!_isExpanded) {
                  notifier.setRemoveMode(false);
                }
              });
            },
            borderRadius: _isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Switch account',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (!_isExpanded && otherAccounts.isNotEmpty) ...[
                    _buildOverlappingAvatars(context, otherAccounts),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded section with smooth size transition
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // List of Accounts
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: switchState.accounts.length,
                      itemBuilder: (context, index) {
                        final account = switchState.accounts[index];
                        final isActive = !account.isMock;

                        return InkWell(
                          onTap: () {
                            if (switchState.isRemoveMode) return;
                            if (isActive) return;
                            notifier.switchActiveAccount(account);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Avatar circle with delete pill badge if in remove mode
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildAvatarCircle(account, size: 40),
                                    if (switchState.isRemoveMode)
                                      Positioned(
                                        top: -6,
                                        left: -6,
                                        child: GestureDetector(
                                          onTap: () => notifier.removeAccount(context, account),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.displayName,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        account.username != null && account.username!.isNotEmpty
                                            ? '@${account.username}'
                                            : 'ID ${account.telegramId}',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive && !switchState.isRemoveMode) ...[
                                  // Add Sign Out row for the active account inside the expanded switcher
                                  TextButton(
                                    onPressed: () => notifier.removeAccount(context, account),
                                    style: TextButton.styleFrom(
                                      foregroundColor: scheme.error,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Options in switch card
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      height: 1,
                    ),
                  ),
                  _buildSwitchOptionRow(
                    context,
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Add another account',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Multiple Telegram account login will be supported soon!')),
                      );
                    },
                  ),
                  _buildSwitchOptionRow(
                    context,
                    icon: switchState.isRemoveMode ? Icons.check_circle_outline_rounded : Icons.manage_accounts_outlined,
                    label: switchState.isRemoveMode ? 'Done removing' : 'Remove account',
                    onTap: () {
                      notifier.toggleRemoveMode();
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // Backup Card Builder
  Widget _buildBackupCard(BuildContext context, bool backupOn) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgR,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (backupOn ? scheme.primary : scheme.outlineVariant).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                backupOn ? Icons.cloud_queue_rounded : Icons.cloud_off_rounded,
                color: backupOn ? scheme.primary : scheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backupOn ? 'Backup is on' : 'Backup is off',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    backupOn
                        ? 'Your files and media are currently backing up to Telegram Drive.'
                        : 'Keep your photos and videos safe by backing them up to your Telegram Drive.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () {
                        ref.read(mediaBackupProvider.notifier).state = !backupOn;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(backupOn ? 'Backup turned off.' : 'Backup enabled!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(backupOn ? 'Turn off backup' : 'Turn on backup'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Action Row Builder
  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: scheme.onSurfaceVariant, size: 20),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  // Switch Options Rows (Add / Remove accounts)
  Widget _buildSwitchOptionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, color: scheme.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Overlapping thumbnails builder
  Widget _buildOverlappingAvatars(BuildContext context, List<TelegramAccount> accounts) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < accounts.length.clamp(0, 2); i++)
            Align(
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surfaceContainer, width: 1.5),
                ),
                child: _buildAvatarCircle(accounts[i], size: 22),
              ),
            ),
          if (accounts.length > 2)
            Align(
              widthFactor: 0.65,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surfaceContainer, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${accounts.length - 2}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Small helper to build the fallback text/image circle for Switcher
  Widget _buildAvatarCircle(TelegramAccount account, {required double size}) {
    final scheme = Theme.of(context).colorScheme;
    final initial = account.firstName.isNotEmpty ? account.firstName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: account.isMock ? scheme.secondaryContainer : scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: account.isMock ? scheme.onSecondaryContainer : scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  // Rich Avatar Widget leveraging existing profile avatar flow
  Widget _buildAvatarWidget(TelegramAccount account, {required double size}) {
    if (account.isMock) {
      return _buildAvatarCircle(account, size: size);
    }
    final auth = ref.watch(authControllerProvider);
    return ProfileAvatar(user: auth.user, size: size);
  }

  void _showHelpFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Feedback'),
        content: const Text(
          'TeleDrive is a cloud drive built on top of the Telegram platform.\n\n'
          'For feedback or bugs, please visit our GitHub repository or contact the DevsDoCode support channel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppConfig.openRepository();
            },
            child: const Text('Visit GitHub'),
          ),
        ],
      ),
    );
  }
}
