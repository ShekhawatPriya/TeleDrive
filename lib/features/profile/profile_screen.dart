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
import 'widgets/storage_swipe_card.dart';
import 'cache_controller.dart';

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

class GitHubIcon extends StatelessWidget {
  const GitHubIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GitHubPainter(color),
      ),
    );
  }
}

class _GitHubPainter extends CustomPainter {
  _GitHubPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    final scaleX = size.width / 16.0;
    final scaleY = size.height / 16.0;
    
    path.moveTo(8 * scaleX, 0 * scaleY);
    
    path.cubicTo(3.58 * scaleX, 0 * scaleY, 0 * scaleX, 3.58 * scaleY, 0 * scaleX, 8 * scaleY);
    path.cubicTo(0 * scaleX, 11.54 * scaleY, 2.29 * scaleX, 14.53 * scaleY, 5.47 * scaleX, 15.59 * scaleY);
    path.cubicTo(5.87 * scaleX, 15.66 * scaleY, 6.02 * scaleX, 15.42 * scaleY, 6.02 * scaleX, 15.21 * scaleY);
    path.cubicTo(6.02 * scaleX, 15.02 * scaleY, 6.01 * scaleX, 14.39 * scaleY, 6.01 * scaleX, 13.72 * scaleY);
    path.cubicTo(4.0 * scaleX, 14.09 * scaleY, 3.48 * scaleX, 13.23 * scaleY, 3.32 * scaleX, 12.78 * scaleY);
    path.cubicTo(3.23 * scaleX, 12.55 * scaleY, 2.84 * scaleX, 11.84 * scaleY, 2.5 * scaleX, 11.65 * scaleY);
    path.cubicTo(2.22 * scaleX, 11.5 * scaleY, 1.82 * scaleX, 11.13 * scaleY, 2.49 * scaleX, 11.12 * scaleY);
    path.cubicTo(3.12 * scaleX, 11.11 * scaleY, 3.57 * scaleX, 11.7 * scaleY, 3.72 * scaleX, 11.94 * scaleY);
    path.cubicTo(4.44 * scaleX, 13.15 * scaleY, 5.59 * scaleX, 12.81 * scaleY, 6.05 * scaleX, 12.6 * scaleY);
    path.cubicTo(6.12 * scaleX, 12.08 * scaleY, 6.33 * scaleX, 11.73 * scaleY, 6.56 * scaleX, 11.53 * scaleY);
    path.cubicTo(4.78 * scaleX, 11.33 * scaleY, 2.92 * scaleX, 10.64 * scaleY, 2.92 * scaleX, 7.58 * scaleY);
    path.cubicTo(2.92 * scaleX, 6.71 * scaleY, 3.23 * scaleX, 5.99 * scaleY, 3.74 * scaleX, 5.43 * scaleY);
    path.cubicTo(3.66 * scaleX, 5.23 * scaleY, 3.38 * scaleX, 4.41 * scaleY, 3.82 * scaleX, 3.31 * scaleY);
    path.cubicTo(3.82 * scaleX, 3.31 * scaleY, 4.49 * scaleX, 3.1 * scaleY, 6.02 * scaleX, 4.13 * scaleY);
    path.cubicTo(6.66 * scaleX, 3.95 * scaleY, 7.34 * scaleX, 3.86 * scaleY, 8.02 * scaleX, 3.86 * scaleY);
    path.cubicTo(8.7 * scaleX, 3.86 * scaleY, 9.38 * scaleX, 3.95 * scaleY, 10.02 * scaleX, 4.13 * scaleY);
    path.cubicTo(11.55 * scaleX, 3.09 * scaleY, 12.22 * scaleX, 3.31 * scaleY, 12.22 * scaleX, 3.31 * scaleY);
    path.cubicTo(12.66 * scaleX, 4.41 * scaleY, 12.38 * scaleX, 5.23 * scaleY, 12.3 * scaleX, 5.43 * scaleY);
    path.cubicTo(12.81 * scaleX, 5.99 * scaleY, 13.12 * scaleX, 6.71 * scaleY, 13.12 * scaleX, 7.58 * scaleY);
    path.cubicTo(13.12 * scaleX, 10.65 * scaleY, 11.25 * scaleX, 11.33 * scaleY, 9.47 * scaleX, 11.53 * scaleY);
    path.cubicTo(9.76 * scaleX, 11.78 * scaleY, 10.01 * scaleX, 12.26 * scaleY, 10.01 * scaleX, 13.01 * scaleY);
    path.cubicTo(10.01 * scaleX, 14.08 * scaleY, 10.0 * scaleX, 14.94 * scaleY, 10.0 * scaleX, 15.21 * scaleY);
    path.cubicTo(10.0 * scaleX, 15.42 * scaleY, 10.15 * scaleX, 15.67 * scaleY, 10.55 * scaleX, 15.59 * scaleY);
    path.cubicTo(13.73 * scaleX, 14.53 * scaleY, 16.0 * scaleX, 11.54 * scaleY, 16.0 * scaleX, 8.0 * scaleY);
    path.cubicTo(16.0 * scaleX, 3.58 * scaleY, 12.42 * scaleX, 0 * scaleY, 8.0 * scaleX, 0 * scaleY);
    
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
