import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/github_icon.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: AppRadii.xlR,
          ),
          child: Icon(
            Icons.cloud_outlined,
            color: scheme.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'TeleDrive',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Your Telegram-powered drive,\nmade transparent.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'TeleDrive helps you organize, preview, stream, and manage files through a clean drive interface while keeping storage backed by Telegram and your configured backend.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/login');
                },
                child: const Text('Get Started'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AppConfig.openRepository();
                },
                icon: GitHubIcon(size: 16, color: scheme.primary),
                label: const Text('GitHub'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            _buildTrustBadge(context, 'Open Source'),
            _buildDividerDot(context),
            _buildTrustBadge(context, 'Telegram-backed'),
            _buildDividerDot(context),
            _buildTrustBadge(context, 'Local Cache Explained'),
            _buildDividerDot(context),
            _buildTrustBadge(context, 'No Confusions'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    );
  }

  Widget _buildDividerDot(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}
