import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import 'profile_avatar.dart';

/// Shared header used across tab screens. Renders a Material 3 `headlineSmall`
/// title (24/32, w400) with a `bodyMedium` muted subtitle, and the user's
/// profile avatar on the right. Optional [trailing] sits between the subtitle
/// column and the avatar — used for the overflow `MenuAnchor` button on the
/// home screen.
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w400,
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
          child: ProfileAvatar(user: auth.user, size: 40),
        ),
      ],
    );
  }
}
