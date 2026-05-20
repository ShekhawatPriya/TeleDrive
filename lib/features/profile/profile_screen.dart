import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import 'theme_controller.dart';
import 'widgets/account_section.dart';
import 'widgets/profile_hero.dart';
import 'widgets/storage_donut_card.dart';
import 'widgets/telegram_status_card.dart';
import 'widgets/theme_picker_cards.dart';
import 'widgets/storage_swipe_card.dart';
import 'cache_controller.dart';
import '../../widgets/github_icon.dart';
import 'widgets/sign_out_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.scrollToStorage = false, super.key});
  final bool scrollToStorage;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final GlobalKey _storageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cacheControllerProvider).refreshCacheStats();
      }
    });
    if (widget.scrollToStorage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _storageKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: AppDurations.long1,
            curve: AppEasing.emphasized,
            alignment: 0.12,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  AccountSectionLabel('Storage Management', key: _storageKey),
                  StorageSwipeCard(used: used, categories: categories),
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
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.mdR,
                            side: BorderSide(
                              color: scheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm + 4,
                              horizontal: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.tag_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'v${AppConfig.appVersion}',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Version',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: scheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.mdR,
                            side: BorderSide(
                              color: scheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => AppConfig.openRepository(),
                            borderRadius: AppRadii.mdR,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm + 4,
                                horizontal: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: scheme.onSurface.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: GitHubIcon(
                                      size: 18,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'GitHub',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Open Source',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AccountSection(
                    children: [
                      AccountActionRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => context.safePush('/privacy'),
                      ),
                      AccountActionRow(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        onTap: () => context.safePush('/terms'),
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
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: theme.colorScheme.surfaceContainerLow,
                            builder: (context) => const SignOutConfirmationSheet(),
                          );
                        },
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


