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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (accesses.isEmpty && !loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_toggle_off_rounded,
                  size: 28,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No activity yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < accesses.length; i++)
          _Row(
            entry: accesses[i],
            isFirst: i == 0,
            isLast: i == accesses.length - 1,
          ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: TextButton.icon(
                onPressed: loading ? null : onLoadMore,
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_downward_rounded, size: 16),
                label: Text(loading ? 'Loading…' : 'Load more'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final ShareAccess entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDownload = entry.action == 'download';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left timeline column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top line spacer
                Container(
                  width: 2,
                  height: 10,
                  color: isFirst
                      ? Colors.transparent
                      : scheme.outlineVariant.withValues(alpha: 0.6),
                ),
                // Circular node container with icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDownload
                        ? Colors.teal.withValues(alpha: 0.08)
                        : scheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDownload
                          ? Colors.teal.withValues(alpha: 0.3)
                          : scheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _iconFor(entry.action),
                      size: 14,
                      color: isDownload ? Colors.teal.shade700 : scheme.primary,
                    ),
                  ),
                ),
                // Bottom line segment
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Right content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _label(entry),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (entry.country != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: AppRadii.smR,
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            entry.country!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(entry.accessedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String action) => switch (action) {
    'download' => Icons.download_outlined,
    'preview' => Icons.visibility_outlined,
    _ => Icons.open_in_new,
  };

  String _label(ShareAccess access) {
    final base = switch (access.action) {
      'download' => 'Downloaded',
      'preview' => 'Previewed',
      _ => 'Viewed',
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
