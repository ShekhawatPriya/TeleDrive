import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/ios/ios_browse.dart';
import '../../../widgets/ios_more_menu.dart';
import 'share_item_menu.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../core/utils/file_type_detector.dart';
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
        plain: true,
        size: 48,
        tooltip: 'Actions for ${share.displayName}',
        sectionsBuilder: (_) => ShareItemMenu.sections(context, ref, share),
      );
      final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            share.displayName,
            maxLines: large ? null : 2,
            overflow: large ? null : TextOverflow.ellipsis,
            style: IosBrowse.body(context),
          ),
          const SizedBox(height: 2),
          Text(
            '${share.fileCount} ${share.fileCount == 1 ? 'file' : 'files'} · ${share.permission.label}',
            style: IosBrowse.footnote(context),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ShareStatus(share: share),
              Text(
                '${share.viewCount} views · ${share.downloadCount} downloads',
                style: IosBrowse.footnote(context),
              ),
            ],
          ),
        ],
      );
      return ShareItemMenu(
        share: share,
        trailingClearance: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: IosBrowse.gutter),
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
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _Thumb(share: share),
                              ),
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
                  indent: large ? 0 : 56,
                  color: IosBrowse.separator(context),
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
    if (theme.platform == TargetPlatform.iOS) return _iosTile(context, ref);
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

  /// iOS: the cover with its caption directly on the page, like Drive's
  /// grid tiles; link state sits under the name rather than over the image.
  Widget _iosTile(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(18);
    return ShareItemMenu(
      share: share,
      trailingClearance: 48,
      child: IosPressable(
        onTap: () => context.safePush('/shared/${share.id}'),
        semanticLabel: share.displayName,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRSuperellipse(
                    borderRadius: radius,
                    child: ColoredBox(
                      color: IosBrowse.fill(context),
                      child: _Thumb(share: share, expand: true),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: RoundedSuperellipseBorder(
                          borderRadius: radius,
                          side: BorderSide(
                            color: IosBrowse.hairline(context),
                            width: .5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
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
            const SizedBox(height: 8),
            Text(
              share.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IosBrowse.subheadline(context, weight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            _ShareStatus(share: share),
            const SizedBox(height: 1),
            Text(
              '${share.viewCount} views · ${share.downloadCount} downloads',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IosBrowse.footnote(context),
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
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // A coloured dot plus a word, so state never relies on colour alone.
      final dot = share.isActive
          ? CupertinoColors.systemGreen
          : share.isExpired && !share.isRevoked
          ? CupertinoColors.systemOrange
          : CupertinoColors.systemGrey;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dot.resolveFrom(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            share.isRevoked
                ? 'Revoked'
                : share.isExpired
                ? 'Expired'
                : 'Active link',
            style: IosBrowse.footnote(
              context,
              color: share.isActive ? scheme.onSurface : null,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
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
    if (theme.platform == TargetPlatform.iOS) return _ios(context, url, scheme);

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

  Widget _ios(BuildContext context, String? url, ColorScheme scheme) {
    final name = share.displayName;
    final Widget glyph = share.isFolder
        ? Center(
            child: Icon(
              CupertinoIcons.folder_fill,
              size: expand ? 52 : 24,
              color: scheme.primary,
            ),
          )
        : IosFileGlyph(
            kind: detectFileKind(name, null),
            extension: extensionOf(name),
          );
    if (expand) {
      return share.isFolder || url == null || url.isEmpty
          ? glyph
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => glyph,
              errorWidget: (_, __, ___) => glyph,
            );
    }
    final radius = BorderRadius.circular(10);
    return SizedBox.square(
      dimension: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRSuperellipse(
            borderRadius: radius,
            child: ColoredBox(
              color: IosBrowse.fill(context),
              child: share.isFolder || url == null || url.isEmpty
                  ? glyph
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => glyph,
                      errorWidget: (_, __, ___) => glyph,
                    ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: IosBrowse.hairline(context),
                    width: .5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
