import 'package:flutter/material.dart';

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
    if (accesses.isEmpty && !loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No activity yet')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in accesses) _Row(entry: entry),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(_iconFor(entry.action), size: 20),
      title: Text(_label(entry)),
      subtitle: Text(_timeAgo(entry.accessedAt)),
      trailing: entry.country != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.country!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
