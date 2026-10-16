import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/share_models.dart';
import '../../../widgets/ios/ios_page.dart';
import 'share_contents.dart';

/// A content-led share summary, with inline statistics and a plain activity list.
class IosShareDetailContent extends StatelessWidget {
  const IosShareDetailContent({
    super.key,
    required this.share,
    required this.stats,
    required this.accesses,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onCopy,
    required this.onShare,
  });
  final Share share;
  final ShareStats? stats;
  final List<ShareAccess> accesses;
  final bool loading, hasMore;
  final VoidCallback onLoadMore, onCopy, onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.link, color: scheme.primary, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(share.displayName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    share.isActive ? 'Active link' : 'Link inactive',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ShareContents(share: share),
        const SizedBox(height: 24),
        Text(
          share.url,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = MediaQuery.textScalerOf(context).scale(17) > 25;
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final action in [
                  ('Copy link', CupertinoIcons.doc_on_doc, onCopy),
                  ('Share', CupertinoIcons.square_arrow_up, onShare),
                ])
                  SizedBox(
                    width: stacked
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: CupertinoButton.tinted(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: action.$3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(action.$2, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(action.$1, textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        // Settings › General › About style: grouped rows, value on the right.
        IosGroup(
          children: [
            IosRow(title: 'Access', value: share.permission.label),
            IosRow(
              title: 'Created',
              value: DateFormat.yMMMd().format(share.createdAt.toLocal()),
            ),
            IosRow(
              title: 'Expires',
              value: share.expiresAt == null
                  ? 'Never'
                  : DateFormat.yMMMd().format(share.expiresAt!.toLocal()),
            ),
          ],
        ),
        IosGroup(
          title: 'Statistics',
          children: [
            IosRow(title: 'Views', value: '${share.viewCount}'),
            IosRow(title: 'Downloads', value: '${share.downloadCount}'),
            IosRow(
              title: 'Unique Viewers',
              value: stats == null ? '—' : '${stats!.uniqueViewers}',
            ),
          ],
        ),
        if (stats?.byCountry.isNotEmpty == true)
          IosGroup(
            title: 'By Country',
            children: [
              for (final country in stats!.byCountry.entries)
                IosRow(
                  title: country.key,
                  value:
                      '${country.value} ${country.value == 1 ? 'view' : 'views'}',
                ),
            ],
          ),
        Text('Activity', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (accesses.isEmpty && !loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 28,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text('No activity yet', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  'Views and downloads will appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        for (final entry in accesses) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.action == 'download'
                      ? CupertinoIcons.arrow_down_circle
                      : CupertinoIcons.eye,
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${switch (entry.action) {
                          'download' => 'Downloaded',
                          'preview' => 'Previewed',
                          _ => 'Viewed',
                        }}${entry.isBot ? ' · Bot' : ''}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (entry.itemName?.isNotEmpty == true)
                        Text(
                          entry.itemName!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      Text(
                        [
                          DateFormat(
                            'd MMM y · h:mm a',
                          ).format(entry.accessedAt.toLocal()),
                          if (entry.country?.isNotEmpty == true) entry.country!,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (entry.userAgent.isNotEmpty)
                        Text(
                          entry.userAgent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: .5,
            thickness: .5,
            indent: 34,
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ],
        if (loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CupertinoActivityIndicator(),
          ),
        if (hasMore && !loading)
          CupertinoButton(
            onPressed: onLoadMore,
            child: const Text('Load more'),
          ),
      ],
    );
  }
}
