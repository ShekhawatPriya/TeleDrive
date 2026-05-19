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
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: AppRadii.smR,
          ),
          child: Text(
            share.url,
            style: theme.textTheme.code(scheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('Copy link'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ShareCounters(share: share, stats: stats),
        const SizedBox(height: AppSpacing.lg),
        if (byCountry.isNotEmpty) ...[
          Text(
            'By country',
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final entry in byCountry.entries)
            ListTile(
              dense: true,
              leading: Icon(Icons.public, color: scheme.onSurfaceVariant),
              title: Text(entry.key),
              trailing: Text(
                '${entry.value}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          'Activity',
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
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
}

class ShareCounters extends StatelessWidget {
  const ShareCounters({required this.share, required this.stats, super.key});
  final Share share;
  final ShareStats? stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Counter(label: 'Views', value: share.viewCount),
        _Counter(label: 'Downloads', value: share.downloadCount),
        _Counter(label: 'Unique', value: stats?.uniqueViewers ?? 0),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.smR,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text('$value', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
