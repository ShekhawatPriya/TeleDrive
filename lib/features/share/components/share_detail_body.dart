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
    final scheme = Theme.of(context).colorScheme;
    final byCountry = stats?.byCountry ?? const {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            share.url,
            style: Theme.of(context).textTheme.code(scheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy link'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ShareCounters(share: share, stats: stats),
        const SizedBox(height: 24),
        if (byCountry.isNotEmpty) ...[
          Text('By country', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final entry in byCountry.entries)
            ListTile(
              dense: true,
              leading: const Icon(Icons.public, size: 20),
              title: Text(entry.key),
              trailing: Text('${entry.value}'),
            ),
          const SizedBox(height: 24),
        ],
        Text('Activity', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
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
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
