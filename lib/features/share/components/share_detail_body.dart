import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/share_models.dart';
import 'access_log_list.dart';

class ShareDetailBody extends StatelessWidget {
  const ShareDetailBody({
    required this.share,
    required this.stats,
    required this.accesses,
    required this.accessesHasMore,
    required this.accessesLoading,
    required this.onLoadMore,
    required this.onCopy,
    required this.onShare,
    super.key,
  });

  final Share share;
  final ShareStats? stats;
  final List<ShareAccess> accesses;
  final bool accessesHasMore;
  final bool accessesLoading;
  final VoidCallback onLoadMore;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byCountry = stats?.byCountry ?? const {};

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Premium Share Link Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadii.mdR,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Sharing Link',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: AppRadii.smR,
                ),
                child: Text(
                  share.url,
                  style: theme.textTheme.code(scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: const Text('Copy link'),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Beautiful Redesigned Analytics counters
        ShareCounters(share: share, stats: stats),
        const SizedBox(height: AppSpacing.lg),

        // Country breakdowns list inside a gorgeous container
        if (byCountry.isNotEmpty) ...[
          _buildSectionHeader(context, 'By country', Icons.public_rounded),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadii.mdR,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                for (final entry
                    in byCountry.entries.toList().asMap().entries) ...[
                  if (entry.key > 0)
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      entry.value.key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value.value} ${entry.value.value == 1 ? 'view' : 'views'}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Activity timeline feed
        _buildSectionHeader(context, 'Activity', Icons.analytics_outlined),
        const SizedBox(height: AppSpacing.xs),
        ShareAccessLogList(
          accesses: accesses,
          loading: accessesLoading,
          hasMore: accessesHasMore,
          onLoadMore: onLoadMore,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class ShareCounters extends StatelessWidget {
  const ShareCounters({required this.share, required this.stats, super.key});
  final Share share;
  final ShareStats? stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _Counter(
          label: 'Views',
          value: share.viewCount,
          icon: Icons.visibility_outlined,
          iconColor: scheme.primary,
          bgColor: scheme.primary.withValues(alpha: 0.08),
        ),
        _Counter(
          label: 'Downloads',
          value: share.downloadCount,
          icon: Icons.file_download_outlined,
          iconColor: Colors.teal.shade700,
          bgColor: Colors.teal.withValues(alpha: 0.08),
        ),
        _Counter(
          label: 'Unique',
          value: stats?.uniqueViewers ?? 0,
          icon: Icons.people_outline_rounded,
          iconColor: Colors.indigo.shade700,
          bgColor: Colors.indigo.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.mdR,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
