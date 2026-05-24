import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How TeleDrive Works',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'TeleDrive combines local TDLib transfer, backend metadata, and Telegram storage without routing private file bytes through the backend.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildFlowStep(
              context: context,
              icon: Icons.phone_iphone_rounded,
              iconColor: scheme.primary,
              title: 'Your Phone / App',
              description:
                  'Reads selected files locally, transfers them through TDLib, and lets you explore files, media, and folders.',
              isFirst: true,
            ),
            _buildFlowStep(
              context: context,
              icon: Icons.dns_outlined,
              iconColor: scheme.secondary,
              title: 'Backend Metadata Layer',
              description:
                  'Stores folder structure, names, shares, upload state, backup fingerprints, and Telegram references. Private file bytes are not uploaded here.',
            ),
            _buildFlowStep(
              context: context,
              icon: Icons.cloud_done_outlined,
              iconColor: scheme.tertiary,
              title: 'Telegram Storage Layer',
              description:
                  'Hosts the transferred file objects referenced by TeleDrive metadata.',
              isLast: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local Cache And TDLib',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Temporary previews and downloaded files live locally for speed. Upload and private download actions require the local TDLib session to stay connected.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStep({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (!isLast) const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
