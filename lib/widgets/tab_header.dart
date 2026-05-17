import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import 'profile_avatar.dart';

/// Shared header widget used across all tab screens to enforce visual
/// consistency.  Renders a branded title in [headlineMedium] with the
/// primary colour, a contextual subtitle below, and the user's profile
/// avatar on the right.
class TabHeader extends ConsumerWidget {
  const TabHeader({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: ProfileAvatar(user: auth.user, size: 42),
        ),
      ],
    );
  }
}
