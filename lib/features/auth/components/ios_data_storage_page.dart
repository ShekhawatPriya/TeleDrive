import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/ios_palette.dart';
import '../../../core/utils/safe_navigation.dart';
import '../../../widgets/ios/ios_page.dart';

/// The iOS answer to "How TeleDrive Stores Your Data", pushed from the
/// welcome screen: a Settings-style hero, where each kind of data lives as
/// one inset group, and plain answers to the questions people ask before
/// signing in. Android keeps its expandable explanation on the landing page.
class IosDataStoragePage extends StatelessWidget {
  const IosDataStoragePage({super.key});

  static Future<void> push(BuildContext context) => Navigator.of(
    context,
  ).push(CupertinoPageRoute<void>(builder: (_) => const IosDataStoragePage()));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IosPage(
      title: 'Your Data',
      compact: true,
      children: [
        const IosSettingsIntro(
          icon: CupertinoIcons.lock_shield_fill,
          color: IosTint.privacy,
          title: 'Your Data',
          description:
              'Your files stay in your own Telegram account. TeleDrive '
              'only keeps what it needs to organize them.',
        ),
        const IosGroup(
          title: 'Where Things Live',
          footer:
              'Files travel directly between this iPhone and Telegram. '
              'They never pass through TeleDrive’s servers.',
          children: [
            IosRow(
              icon: CupertinoIcons.paperplane_fill,
              color: IosTint.telegramDrive,
              title: 'Telegram',
              subtitle: 'Your original photos, videos and files.',
            ),
            IosRow(
              icon: CupertinoIcons.square_stack_3d_up_fill,
              color: IosTint.photoBackup,
              title: 'TeleDrive Server',
              subtitle:
                  'Folder names, shared links, upload progress and '
                  'references to your files, never the files themselves.',
            ),
            IosRow(
              icon: CupertinoIcons.device_phone_portrait,
              color: IosTint.storage,
              title: 'This iPhone',
              subtitle:
                  'Thumbnails, previews and files you open, cached so '
                  'browsing feels instant.',
            ),
          ],
        ),
        const IosGroup(
          title: 'Common Questions',
          children: [
            IosRow(
              title: 'Does clearing the cache delete files?',
              subtitle:
                  'No. It only removes temporary copies on this iPhone. '
                  'Your originals stay in Telegram.',
            ),
            IosRow(
              title: 'How is my sign-in protected?',
              subtitle:
                  'Your Telegram session keys are kept in the iOS Keychain '
                  'on this device.',
            ),
            IosRow(
              title: 'What can TeleDrive read on my iPhone?',
              subtitle:
                  'Only the files you choose. Photo backup reads your '
                  'library only after you turn it on.',
            ),
            IosRow(
              title: 'Why stay connected to Telegram?',
              subtitle:
                  'Uploading and opening private files uses this iPhone’s '
                  'own Telegram session.',
            ),
          ],
        ),
        IosGroup(
          children: [
            IosRow(
              title: 'Privacy Policy',
              onTap: () => context.safePush('/privacy'),
            ),
            IosRow(
              title: 'Source Code',
              trailing: Icon(
                CupertinoIcons.arrow_up_right,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              onTap: AppConfig.openRepository,
            ),
          ],
        ),
      ],
    );
  }
}
