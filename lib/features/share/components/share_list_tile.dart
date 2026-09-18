import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../models/share_models.dart';

class ShareListTile extends StatelessWidget {
  const ShareListTile({required this.share, super.key});
  final Share share;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: theme.platform == TargetPlatform.iOS
            ? Colors.transparent
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.safePush('/shared/${share.id}'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumb(share: share),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            share.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${share.isFolder ? 'Folder · ' : ''}${share.fileCount} ${share.fileCount == 1 ? 'file' : 'files'} · ${share.permission.label}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ShareStatus(share: share),
                    Text(
                      '${share.viewCount} views',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${share.downloadCount} downloads',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShareCardTile extends StatelessWidget {
  const ShareCardTile({required this.share, super.key});
  final Share share;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.platform == TargetPlatform.iOS
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.safePush('/shared/${share.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumb(share: share, expand: true),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _ShareStatus(share: share),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${share.viewCount} views · ${share.downloadCount} downloads',
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
    );
  }
}

class _ShareStatus extends StatelessWidget {
  const _ShareStatus({required this.share});
  final Share share;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: share.isActive
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        share.isRevoked
            ? 'Revoked'
            : share.isExpired
            ? 'Expired'
            : 'Active link',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: share.isActive
              ? scheme.onSecondaryContainer
              : scheme.onSurface,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.share, this.expand = false});

  final Share share;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final url = share.coverThumbnailUrl;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isFolder = share.isFolder;
    final placeholder = Container(
      width: expand ? double.infinity : 52,
      height: expand ? double.infinity : 52,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: expand ? BorderRadius.zero : AppRadii.smR,
      ),
      child: Center(
        child: Icon(
          isFolder ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
          size: expand ? 36 : 24,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );

    if (isFolder || url == null || url.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: expand ? BorderRadius.zero : AppRadii.smR,
      child: CachedNetworkImage(
        imageUrl: url,
        width: expand ? double.infinity : 52,
        height: expand ? double.infinity : 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
