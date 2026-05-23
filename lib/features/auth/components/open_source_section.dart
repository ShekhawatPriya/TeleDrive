import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/social_icons.dart';

class OpenSourceSection extends StatelessWidget {
  const OpenSourceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: GitHubIcon(size: 28, color: scheme.onSurface),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Open Source by Design',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'TeleDrive is completely open source. Anyone can inspect our code, audit storage processes, self-host the backend, or check how sessions and local cache keys are handled.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                AppConfig.openRepository();
              },
              icon: GitHubIcon(size: 16, color: scheme.primary),
              label: const Text('View GitHub Repository'),
            ),
          ],
        ),
      ),
    );
  }
}
