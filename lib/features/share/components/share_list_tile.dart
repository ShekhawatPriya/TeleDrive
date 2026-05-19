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
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
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
                icon: Icons.file_download_outlined, value: share.downloadCount),
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder = Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.smR,
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
        width: 56, height: 56,
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
