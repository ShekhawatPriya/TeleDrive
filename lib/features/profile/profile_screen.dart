import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import 'theme_controller.dart';
import 'widgets/account_section.dart';
import 'widgets/profile_hero.dart';
import 'widgets/storage_donut_card.dart';
import 'widgets/telegram_status_card.dart';
import 'widgets/theme_picker_cards.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = auth.user;
    final files = drive.files;
    final used = drive.state.usedStorage;
    final categories = buildStorageCategories(files, scheme);

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/drive');
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () {
                  if (GoRouter.of(context).canPop()) {
                    context.pop();
                  } else {
                    context.go('/drive');
                  }
                },
              ),
              title: const Text('Account'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                112,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  ProfileHero(user: user),
                  const SizedBox(height: AppSpacing.md),
                  TelegramStatusCard(
                    connected: auth.telegramConnected,
                    telegramId: user?.telegramId,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AccountSectionLabel('Storage'),
                  StorageDonutCard(used: used, categories: categories),
                  const SizedBox(height: AppSpacing.lg),
                  const AccountSectionLabel('Profile'),
                  AccountSection(
                    children: [
                      AccountActionRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Username',
                        value: user?.username == null
                            ? 'Not set'
                            : '@${user!.username}',
                      ),
                      AccountActionRow(
                        icon: Icons.badge_outlined,
                        label: 'Telegram ID',
                        value: user?.telegramId == null
                            ? '-'
                            : '${user!.telegramId}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AccountSectionLabel('Appearance'),
                  ThemePickerCards(
                    mode: ref.watch(themeControllerProvider).mode,
                    onChanged: ref.read(themeControllerProvider).setMode,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AccountSectionLabel('About'),
                  AccountSection(
                    children: [
                      const AccountActionRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Version',
                        value: '1.0.0',
                      ),
                      AccountActionRow(
                        icon: Icons.code_rounded,
                        label: 'Open Source',
                        value: 'GitHub',
                        onTap: () => AppConfig.openRepository(),
                      ),
                      AccountActionRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => context.push('/privacy'),
                      ),
                      AccountActionRow(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        onTap: () => context.push('/terms'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AccountSection(
                    children: [
                      AccountActionRow(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        destructive: true,
                        onTap: () =>
                            ref.read(authControllerProvider).logout(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'TeleDrive — A DevsDoCode Project',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
