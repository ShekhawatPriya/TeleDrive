import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CommunityPromiseList extends StatelessWidget {
  const CommunityPromiseList({super.key});

  static const _items = [
    (
      Icons.groups_2_outlined,
      'Join the official DevsDoCode community for support, updates, and announcements.',
    ),
    (
      Icons.logout_rounded,
      'You can leave the Telegram channel or group anytime from Telegram.',
    ),
    (
      Icons.cloud_off_outlined,
      'This does not affect your cloud storage, files, folders, or Telegram Drive functionality.',
    ),
    (
      Icons.verified_user_outlined,
      'Your Telegram session is used only for the requested community join action and your existing drive operations.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Our Transparency Promise',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .24),
            borderRadius: AppRadii.mdR,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _items[i].$1,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _items[i].$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < _items.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
