import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_navigation.dart';

class FinalCtaAndFooter extends StatelessWidget {
  const FinalCtaAndFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ready to open your drive?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sign in to connect your Telegram-backed library and start managing files beautifully.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            context.safePush('/login');
          },
          style: FilledButton.styleFrom(minimumSize: const Size(200, 44)),
          child: const Text('Get Started'),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'By continuing, you can review how TeleDrive handles storage, cache, and account data in the Privacy Policy and Terms of Service.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.safePush('/privacy');
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Privacy Policy'),
            ),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.safePush('/terms');
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Terms of Service'),
            ),
          ],
        ),
      ],
    );
  }
}
