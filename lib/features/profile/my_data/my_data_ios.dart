part of '../my_data_screen.dart';

extension _IosMyData on _MyDataScreenState {
  Widget _buildIosData(
    BuildContext context,
    AuthController auth,
    StorageSummary summary,
  ) {
    final connected = auth.telegramConnected == true;
    return IosPage(
      title: 'My Data',
      compact: true,
      children: [
        IosSettingsIntro(
          icon: CupertinoIcons.hand_raised_fill,
          color: IosTint.privacy,
          title: 'My Data',
          description:
              'Review the information stored with TeleDrive and the copies kept on this iPhone.',
          onLearnMore: () => context.safePush('/privacy'),
        ),
        IosGroup(
          title: 'Account',
          children: [
            IosRow(
              title: auth.user?.displayName ?? 'Telegram account',
              subtitle: auth.user?.username == null
                  ? null
                  : '@${auth.user!.username}',
              icon: CupertinoIcons.person_fill,
              color: IosTint.neutral,
            ),
            IosRow(
              title: 'Telegram Session',
              value: connected ? 'Connected' : 'Not connected',
              icon: CupertinoIcons.lock_shield_fill,
              color: IosTint.session,
            ),
            IosRow(
              title: 'Telegram Drive',
              subtitle: '${summary.totalFiles} files',
              value: formatFileSize(summary.totalBytes),
              icon: CupertinoIcons.tray_2_fill,
              color: IosTint.telegramDrive,
              onTap: () => context.safePush('/profile'),
            ),
          ],
        ),
        const IosGroup(
          title: 'Where Your Data Lives',
          footer:
              'Private file contents move directly between this iPhone and Telegram. TeleDrive’s server keeps file details, folders, share settings and Telegram references.',
          children: [
            IosRow(
              title: 'File Contents',
              value: 'Telegram',
              icon: CupertinoIcons.cloud_fill,
            ),
            IosRow(
              title: 'Library Details',
              value: 'TeleDrive Server',
              icon: CupertinoIcons.folder_fill,
            ),
            IosRow(
              title: 'Downloads & Previews',
              value: 'This iPhone',
              icon: CupertinoIcons.device_phone_portrait,
            ),
          ],
        ),
        IosGroup(
          title: 'Manage Your Data',
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
              color: IosTint.freeUpSpace,
              onTap: () => context.safePush('/profile/free-up-space'),
            ),
          ],
        ),
        IosGroup(
          title: 'Learn More',
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
