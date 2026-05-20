import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/auth_user.dart';
import '../../../widgets/profile_avatar.dart';
import '../cache_controller.dart';

class ProfileHero extends ConsumerWidget {
  const ProfileHero({required this.user, super.key});

  final AuthUser? user;

  Future<void> _openTelegramProfile(BuildContext context) async {
    final username = user?.username?.trim();
    if (username == null || username.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a Telegram username to manage your profile.'),
        ),
      );
      return;
    }
    final uri = Uri.parse('https://t.me/$username');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cacheState = ref.watch(cacheControllerProvider).state;

    final displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : 'TeleDrive user';
    final subtitle = user?.username != null
        ? '@${user!.username}'
        : 'ID ${user?.telegramId ?? '-'}';

    // Status dot color based on cache health
    final dotColor = switch (cacheState.status) {
      'Clean' => Colors.green,
      'Moderate' => scheme.primary,
      _ => Colors.orange,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.18),
                      scheme.tertiary.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: 3,
                    ),
                  ),
                  child: ProfileAvatar(user: user, size: 96),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Tooltip(
                  message: 'Cache Status: ${cacheState.status}',
                  child: Container(
                    width: 18,
                    height: 18,
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
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: () => _openTelegramProfile(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Manage account'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm - 2,
              ),
              shape: const StadiumBorder(),
              textStyle: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
