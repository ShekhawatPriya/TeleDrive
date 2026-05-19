import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/share_models.dart';

class ShareAccessLogList extends StatelessWidget {
  const ShareAccessLogList({
    required this.accesses,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
    super.key,
  });

  final List<ShareAccess> accesses;
  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (accesses.isEmpty && !loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            'No activity yet',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in accesses) _Row(entry: entry),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: TextButton(
                onPressed: loading ? null : onLoadMore,
                child: Text(loading ? 'Loading…' : 'Load more'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final ShareAccess entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(_iconFor(entry.action), color: scheme.onSurfaceVariant),
      title: Text(_label(entry)),
      subtitle: Text(_timeAgo(entry.accessedAt)),
      trailing: entry.country != null
          ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: AppRadii.smR,
              ),
              child: Text(
                entry.country!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            )
          : null,
    );
  }

  IconData _iconFor(String action) => switch (action) {
        'download' => Icons.download_outlined,
        'preview' => Icons.visibility_outlined,
        _ => Icons.open_in_new,
      };

  String _label(ShareAccess access) {
    final base = switch (access.action) {
      'download' => 'Download',
      'preview' => 'Preview',
      _ => 'View',
    };
    final item = access.itemName == null ? '' : ' · ${access.itemName}';
    return '$base$item';
  }

  String _timeAgo(DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 48) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }
}
