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
    (
      Icons.info_outline_rounded,
      'If Telegram refuses the join, login still completes normally.',
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
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in _items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.$1, color: scheme.onSurfaceVariant, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.$2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
