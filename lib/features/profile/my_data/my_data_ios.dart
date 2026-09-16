part of '../my_data_screen.dart';

extension _IosMyData on _MyDataScreenState {
  Widget _buildIosData(
    BuildContext context,
    AuthController auth,
    StorageSummary summary,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final connected = auth.telegramConnected == true;
    return IosPage(
      title: 'My Data',
      children: [
        const SizedBox(height: 8),
        Center(
          child: Icon(
            CupertinoIcons.hand_raised_fill,
            size: 52,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your files. Your account.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        const IosNote(
          'Manage the information stored with TeleDrive and the copies kept on this iPhone.',
        ),
        IosGroup(
          title: 'ACCOUNT',
          children: [
            IosRow(
              title: auth.user?.displayName ?? 'Telegram account',
              subtitle: auth.user?.username == null
                  ? null
                  : '@${auth.user!.username}',
              icon: CupertinoIcons.person_fill,
              color: CupertinoColors.systemGrey,
            ),
            IosRow(
              title: 'Telegram Session',
              value: connected ? 'Connected' : 'Not connected',
              icon: CupertinoIcons.lock_shield_fill,
              color: CupertinoColors.systemGreen,
            ),
            IosRow(
              title: 'Telegram Drive',
              subtitle: '${summary.totalFiles} files',
              value: formatFileSize(summary.totalBytes),
              icon: CupertinoIcons.tray_2_fill,
              onTap: () => context.safePush('/profile'),
            ),
          ],
        ),
        IosGroup(
          title: 'WHERE YOUR DATA LIVES',
          children: const [
            IosRow(
              title: 'Files in Telegram',
              subtitle:
                  'Private file bytes are transferred directly between this device and your Telegram account.',
              icon: CupertinoIcons.cloud_fill,
            ),
            IosRow(
              title: 'Library information',
              subtitle:
                  'TeleDrive’s backend stores file metadata, folders, share settings and Telegram references.',
              icon: CupertinoIcons.folder_fill,
            ),
            IosRow(
              title: 'Copies on this iPhone',
              subtitle:
                  'Downloads, thumbnails and previews use local storage. Manage them in Cache & Storage.',
              icon: CupertinoIcons.device_phone_portrait,
            ),
          ],
        ),
        IosGroup(
          title: 'MANAGE YOUR DATA',
          children: [
            IosRow(
              title: 'Export Account Data',
              icon: CupertinoIcons.square_arrow_up,
              onTap: () => showCupertinoDialog<void>(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('Export your data'),
                  content: const Text(
                    'For a complete Telegram export, open Telegram Desktop → Settings → Advanced → Export Telegram data.\n\nFor individual files, select them in TeleDrive and choose Download.',
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
            IosRow(
              title: 'Free Up Space',
              icon: CupertinoIcons.device_phone_portrait,
              color: CupertinoColors.systemGreen,
              onTap: () => context.safePush('/profile/free-up-space'),
            ),
          ],
        ),
        IosGroup(
          title: 'LEARN MORE',
          children: [
            IosRow(
              title: 'Telegram Privacy Policy',
              icon: CupertinoIcons.hand_raised,
              onTap: () => _launchUrl('https://telegram.org/privacy'),
            ),
            IosRow(
              title: 'Telegram Security FAQ',
              icon: CupertinoIcons.lock_shield,
              onTap: () =>
                  _launchUrl('https://telegram.org/faq#q-is-telegram-secure'),
            ),
          ],
        ),
      ],
    );
  }
}
