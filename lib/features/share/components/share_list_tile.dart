import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/share_models.dart';

class ShareListTile extends StatelessWidget {
  const ShareListTile({required this.share, super.key});

  final Share share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      onTap: () => context.push('/shared/${share.id}'),
      leading: _Thumb(url: share.coverThumbnailUrl),
      title: Text(
        share.primaryName ?? 'Untitled share',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _subtitle(share),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Counter(icon: Icons.visibility_outlined, value: share.viewCount),
            const SizedBox(height: 4),
            _Counter(
              icon: Icons.file_download_outlined,
              value: share.downloadCount,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Share share) {
    final count = share.itemCount ?? share.items.length;
    final countLabel = count == 1 ? '1 item' : '$count items';
    return '$countLabel · Anyone with link';
  }
}

class ShareCardTile extends StatelessWidget {
  const ShareCardTile({required this.share, super.key});

  final Share share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdR),
      child: InkWell(
        borderRadius: AppRadii.mdR,
        onTap: () => context.push('/shared/${share.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.md),
                ),
                child: _Thumb(url: share.coverThumbnailUrl, expand: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.primaryName ?? 'Untitled share',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _cardSubtitle(share),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Counter(
                        icon: Icons.visibility_outlined,
                        value: share.viewCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cardSubtitle(Share share) {
    final count = share.itemCount ?? share.items.length;
    final countLabel = count == 1 ? '1 item' : '$count items';
    return '$countLabel · Anyone with link';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, this.expand = false});
  final String? url;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder = Container(
      width: expand ? double.infinity : 56,
      height: expand ? double.infinity : 56,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: expand ? BorderRadius.zero : AppRadii.smR,
      ),
      child: Icon(
        Icons.insert_drive_file_outlined,
        color: scheme.onSecondaryContainer,
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: AppRadii.smR,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: expand ? double.infinity : 56,
        height: expand ? double.infinity : 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
