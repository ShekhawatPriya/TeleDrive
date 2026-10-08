part of '../account_bottom_sheet.dart';

extension _AccountSheetTdlibChip on _AccountBottomSheetState {
  void _showTdlibInfoDialog(BuildContext context, bool? connected) {
    final scheme = Theme.of(context).colorScheme;
    final isDisconnected = connected != true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogTheme = Theme.of(dialogContext);
        return AlertDialog(
          icon: Icon(
            Icons.lock_outline_rounded,
            size: 38,
            color: scheme.primary,
          ),
          title: const Text('What is TDLib?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TDLib is the official Telegram client library, running '
                  'directly on your device. TeleDrive uses it to upload and '
                  'download your files privately, without going through any '
                  'third-party server.',
                  style: dialogTheme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your files travel straight between your phone and Telegram. '
                  'Nothing is stored on our servers, and your messages and '
                  'chats stay completely untouched — TeleDrive only handles '
                  'files you choose to back up.',
                  style: dialogTheme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'This connection lives entirely on this device. Signing out '
                  'clears it, and you can manage your Telegram account at any '
                  'time from the official Telegram app.',
                  style: dialogTheme.textTheme.bodyMedium,
                ),
                if (isDisconnected) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Right now this device isn\'t connected to Telegram. '
                    'Sign in again from the account screen to restore the link.',
                    style: dialogTheme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}
