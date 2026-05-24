import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StorageSeparationSection extends StatelessWidget {
  const StorageSeparationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Understanding Storage & Cache',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'TeleDrive separates Telegram-hosted file objects, backend metadata, and temporary local cache.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdR,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: AppRadii.smR,
                  ),
                  child: Icon(
                    Icons.cloud_done_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Telegram File Objects',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.08),
                              borderRadius: AppRadii.xsR,
                            ),
                            child: Text(
                              'CLOUD STORAGE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Original files are transferred by local TDLib and referenced from Telegram. Folder names, shares, refs, and backup state live in the backend metadata database.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildBulletItem(
                        context,
                        'Private file bytes are not uploaded through TeleDrive backend servers',
                      ),
                      _buildBulletItem(
                        context,
                        'Reconnect local TDLib on a supported device before private open/download',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdR,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: AppRadii.smR,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Local Device Cache',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: AppRadii.xsR,
                            ),
                            child: const Text(
                              '100% SAFE TO CLEAR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Temporary device copies of thumbnails, small media previews, and opened documents stored locally. Used only to make browsing load instantly.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildBulletItem(
                        context,
                        'Clearing cache will not delete Telegram-hosted originals',
                      ),
                      _buildBulletItem(
                        context,
                        'Automatically recycled for smooth operation',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5.5, right: 8.0),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
