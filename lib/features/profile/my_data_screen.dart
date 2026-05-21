import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';

class MyDataScreen extends ConsumerWidget {
  const MyDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/drive');
            }
          },
        ),
        title: const Text('Your data in Telegram Drive'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg + 4,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large centered premium Telegram shield graphic
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.xl + 8,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner soft aura / shadow
                      Icon(
                        Icons.shield_rounded,
                        size: 130,
                        color: scheme.primary.withValues(alpha: 0.1),
                      ),
                      // Outer main brand shield
                      Icon(
                        Icons.shield_rounded,
                        size: 110,
                        color: scheme.primary,
                      ),
                      // Padlock overlay representing world-class security
                      Icon(
                        Icons.lock_rounded,
                        size: 42,
                        color: scheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),

              // Title Headline
              Text(
                'Your photos and videos, and their data, are safe within Telegram Drive',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  height: 1.35,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xl + 4),

              // Bullet Points (Icon + text rows)
              _buildBulletRow(
                context,
                icon: Icons.lock_outline_rounded,
                text: 'We use world-class security to protect the photos that you back up or share',
              ),
              const SizedBox(height: AppSpacing.lg + 4),

              _buildBulletRow(
                context,
                icon: Icons.visibility_off_outlined,
                text: "We don't sell your photos for ads or use them to target ads to you",
              ),
              const SizedBox(height: AppSpacing.lg + 4),

              _buildBulletRow(
                context,
                icon: Icons.info_outline_rounded,
                text: 'You control how you share your photos',
              ),
              const SizedBox(height: AppSpacing.xxl + 8),

              // Footer with underlined Telegram Privacy Policy link
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Visit the ',
                    ),
                    TextSpan(
                      text: 'Telegram Privacy Policy',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          context.safePush('/privacy');
                        },
                    ),
                    const TextSpan(
                      text: ' to discover all the ways that Telegram Drive keeps your memories safe.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletRow(BuildContext context, {required IconData icon, required String text}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        const SizedBox(width: AppSpacing.md + 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
