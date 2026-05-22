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
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.mdR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadii.mdR,
        onTap: () => context.safePush('/shared/${share.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _Thumb(share: share),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      share.primaryName ?? 'Untitled share',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(share),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CounterBadge(
                    icon: Icons.visibility_outlined,
                    value: share.viewCount,
                    color: scheme.primary.withValues(alpha: 0.08),
                    textColor: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  _CounterBadge(
                    icon: Icons.file_download_outlined,
                    value: share.downloadCount,
                    color: Colors.teal.withValues(alpha: 0.08),
                    textColor: Colors.teal.shade700,
                  ),
                ],
              ),
            ],
          ),
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
    final count = share.itemCount ?? share.items.length;
    final countLabel = count == 1 ? '1 item' : '$count items';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.mdR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.mdR,
        child: InkWell(
          borderRadius: AppRadii.mdR,
          onTap: () => context.safePush('/shared/${share.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _Thumb(share: share, expand: true)),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          countLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      share.primaryName ?? 'Untitled share',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CounterBadge(
                          icon: Icons.visibility_outlined,
                          value: share.viewCount,
                          color: scheme.primary.withValues(alpha: 0.08),
                          textColor: scheme.primary,
                        ),
                        _CounterBadge(
                          icon: Icons.file_download_outlined,
                          value: share.downloadCount,
                          color: Colors.teal.withValues(alpha: 0.08),
                          textColor: Colors.teal.shade700,
                        ),
                      ],
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.share, this.expand = false});

  final Share share;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final url = share.coverThumbnailUrl;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Guess file type based on primary name
    final name = share.primaryName?.toLowerCase() ?? '';
    final hasExt = name.contains('.') && !name.endsWith('.');
    final isFolder = !hasExt;

    // Determine gradient colors and modern icon depending on predicted mime-type/folder
    List<Color> gradientColors;
    IconData iconData;

    if (isFolder) {
      gradientColors = [Colors.amber.shade400, Colors.orange.shade700];
      iconData = Icons.folder_open_rounded;
    } else if (name.endsWith('.pdf')) {
      gradientColors = [Colors.red.shade400, Colors.red.shade700];
      iconData = Icons.picture_as_pdf_outlined;
    } else if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.heic') ||
        name.endsWith('.webp')) {
      gradientColors = [Colors.purple.shade300, Colors.indigo.shade500];
      iconData = Icons.image_outlined;
    } else if (name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv')) {
      gradientColors = [Colors.teal.shade300, Colors.cyan.shade600];
      iconData = Icons.play_circle_outline_rounded;
    } else {
      gradientColors = [
        scheme.secondaryContainer,
        scheme.secondary.withValues(alpha: 0.6),
      ];
      iconData = Icons.insert_drive_file_outlined;
    }

    Widget placeholder = Container(
      width: expand ? double.infinity : 52,
      height: expand ? double.infinity : 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: expand ? BorderRadius.zero : AppRadii.smR,
      ),
      child: Center(
        child: Icon(iconData, size: expand ? 36 : 24, color: Colors.white),
      ),
    );

    if (url == null || url.isEmpty) {
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

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.icon,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final int value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
