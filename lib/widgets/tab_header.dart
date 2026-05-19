import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import 'profile_avatar.dart';

/// Shared header widget used across all tab screens to enforce visual
/// consistency.  Renders a branded title in [headlineMedium] with the
/// primary colour, a contextual subtitle below, and the user's profile
/// avatar on the right.  When [trailing] is provided it is rendered
/// immediately to the left of the avatar (used for the iOS-style three-dot
/// menu beside the profile icon on the home screen).
class TabHeader extends ConsumerWidget {
  const TabHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: ProfileAvatar(user: auth.user, size: 42),
        ),
      ],
    );
  }
}
