import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/share_models.dart';

class ShareResultView extends StatelessWidget {
  const ShareResultView({
    required this.share,
    required this.onCopy,
    required this.onShare,
    required this.onDone,
    super.key,
  });

  final Share share;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canDownload = share.permission == SharePermission.download;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_rounded,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Link ready', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    canDownload
                        ? 'Anyone with this link can view and download.'
                        : 'Anyone with this link can preview.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: AppRadii.smR,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  share.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.code(scheme.onSurface),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filledTonal(
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                tooltip: 'Copy',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onShare,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share link'),
        ),
        const SizedBox(height: AppSpacing.xxs),
        TextButton(
          onPressed: onDone,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
