import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_onboarding.dart';

class CommunityTargetPanel extends StatelessWidget {
  const CommunityTargetPanel({required this.targets, super.key});

  final List<CommunityTarget> targets;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: AppRadii.mdR,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            for (var index = 0; index < targets.length; index++) ...[
              Expanded(child: _TargetItem(target: targets[index])),
              if (index != targets.length - 1)
                SizedBox(
                  height: 56,
                  child: VerticalDivider(color: scheme.outlineVariant),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetItem extends StatelessWidget {
  const _TargetItem({required this.target});

  final CommunityTarget target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = target.kind == 'group'
        ? Icons.groups_2_rounded
        : Icons.campaign_rounded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.onPrimaryContainer, size: 20),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          target.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          target.name,
          style: theme.textTheme.titleSmall,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
