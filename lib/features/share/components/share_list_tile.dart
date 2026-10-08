import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/ios_more_menu.dart';
import 'share_item_menu.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../models/share_models.dart';

class ShareListTile extends ConsumerWidget {
  const ShareListTile({required this.share, super.key});
  final Share share;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (theme.platform == TargetPlatform.iOS) {
      final more = IosMoreButton(
        size: 44,
        visualSize: 34,
        tooltip: 'Actions for ${share.displayName}',
        sectionsBuilder: (_) => ShareItemMenu.sections(context, ref, share),
      );
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            share.displayName,
            maxLines: MediaQuery.textScalerOf(context).scale(1) >= 1.5
                ? null
                : 2,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${share.fileCount} ${share.fileCount == 1 ? 'file' : 'files'} · ${share.permission.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _ShareStatus(share: share),
              Text(
                '${share.viewCount} views',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${share.downloadCount} downloads',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      );
      final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      return ShareItemMenu(
        share: share,
        trailingClearance: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                InkWell(
                  onTap: () => context.safePush('/shared/${share.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: large
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _Thumb(share: share),
                                  const Spacer(),
                                  more,
                                ],
                              ),
                              const SizedBox(height: 12),
                              copy,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Thumb(share: share),
                              const SizedBox(width: 12),
                              Expanded(child: copy),
                              const SizedBox(width: 4),
                              more,
                            ],
                          ),
                  ),
                ),
                Divider(
                  height: .5,
                  thickness: .5,
                  indent: large ? 0 : 52,
                  color: scheme.outlineVariant.withValues(alpha: .45),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

class ShareCardTile extends ConsumerWidget {
  const ShareCardTile({required this.share, super.key});
  final Share share;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ShareItemMenu(
      share: share,
      trailingClearance: 48,
      child: Material(
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
                    if (theme.platform == TargetPlatform.iOS)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IosMoreButton(
                          size: 44,
                          visualSize: 34,
                          tooltip: 'Actions for ${share.displayName}',
                          sectionsBuilder: (_) =>
                              ShareItemMenu.sections(context, ref, share),
                        ),
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
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Text(
        share.isRevoked
            ? 'Revoked'
            : share.isExpired
            ? 'Expired'
            : 'Active link',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: share.isActive ? scheme.primary : scheme.onSurfaceVariant,
        ),
      );
    }
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
      width: expand
          ? double.infinity
          : (theme.platform == TargetPlatform.iOS ? 40 : 52),
      height: expand
          ? double.infinity
          : (theme.platform == TargetPlatform.iOS ? 40 : 52),
      decoration: BoxDecoration(
        color: theme.platform == TargetPlatform.iOS
            ? Colors.transparent
            : scheme.secondaryContainer,
        borderRadius: expand ? BorderRadius.zero : AppRadii.smR,
      ),
      child: Center(
        child: Icon(
          theme.platform == TargetPlatform.iOS
              ? (isFolder ? CupertinoIcons.folder_fill : CupertinoIcons.doc)
              : (isFolder
                    ? Icons.folder_outlined
                    : Icons.insert_drive_file_outlined),
          size: expand
              ? 36
              : theme.platform == TargetPlatform.iOS
              ? (isFolder ? 36 : 32)
              : 24,
          color: theme.platform == TargetPlatform.iOS
              ? (isFolder ? scheme.primary : scheme.onSurfaceVariant)
              : scheme.onSecondaryContainer,
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
        width: expand
            ? double.infinity
            : (theme.platform == TargetPlatform.iOS ? 40 : 52),
        height: expand
            ? double.infinity
            : (theme.platform == TargetPlatform.iOS ? 40 : 52),
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
