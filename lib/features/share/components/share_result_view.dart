import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Link ready',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Anyone with this link can ${share.permission == SharePermission.download ? "view and download" : "preview"}.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            share.url,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}
