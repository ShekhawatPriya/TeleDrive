part of '../free_up_space_screen.dart';

void _showFreeUpSpaceInfoDialog(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About Backup & Space'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How does Free Up Space work?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Free up space deletes the local cache files (thumbnails, preview files, and cached downloads) stored on this device. These files have already been safely uploaded to your Telegram Cloud Drive.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Will my files be deleted from Telegram?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No. Your files remain completely safe in your Telegram Cloud Drive. You can stream, preview, or download them again at any time within TeleDrive.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
