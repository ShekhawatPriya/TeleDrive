import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/ios_palette.dart';
import '../../core/utils/file_type_detector.dart';
import '../../widgets/ios/ios_page.dart';
import 'storage_summary_controller.dart';
import 'cache_controller.dart';
import 'settings_screen.dart';

class IosStoragePage extends StatelessWidget {
  const IosStoragePage({
    super.key,
    required this.summary,
    required this.error,
    required this.cache,
    required this.onRefresh,
  });
  final StorageSummary? summary;
  final String? error;
  final CacheState cache;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = summary;
    return IosPage(
      title: 'Telegram Drive',
      onRefresh: onRefresh,
      onBack: () => context.canPop() ? context.pop() : context.go('/drive'),
      children: [
        if (data == null) ...[
          if (error == null)
            const Center(child: CupertinoActivityIndicator())
          else
            IosNote(error!),
          CupertinoButton(onPressed: onRefresh, child: const Text('Refresh')),
        ] else ...[
          const SizedBox(height: 12),
          Icon(
            CupertinoIcons.tray_2_fill,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            formatFileSize(data.totalBytes),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${data.totalFiles} files · Unlimited storage',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          if (error != null)
            const IosNote(
              'Showing your last loaded storage usage. Pull down to refresh.',
            ),
          IosGroup(
            title: 'In Telegram',
            children: [
              IosRow(
                title: 'Photos',
                subtitle: '${data.imageCount} items',
                value: formatFileSize(data.imageBytes),
                icon: CupertinoIcons.photo_fill,
                color: IosTint.photos,
              ),
              IosRow(
                title: 'Videos',
                subtitle: '${data.videoCount} items',
                value: formatFileSize(data.videoBytes),
                icon: CupertinoIcons.videocam_fill,
                color: IosTint.videos,
              ),
              IosRow(
                title: 'Documents',
                subtitle: '${data.documentCount} items',
                value: formatFileSize(data.documentBytes),
                icon: CupertinoIcons.doc_fill,
                color: IosTint.documents,
              ),
              IosRow(
                title: 'Audio',
                subtitle: '${data.audioCount} items',
                value: formatFileSize(data.audioBytes),
                icon: CupertinoIcons.music_note,
                color: IosTint.audio,
              ),
              IosRow(
                title: 'Other files',
                subtitle: '${data.otherCount} items',
                value: formatFileSize(data.otherBytes),
                icon: CupertinoIcons.archivebox_fill,
                color: IosTint.other,
              ),
            ],
          ),
        ],
        IosGroup(
          title: 'On This iPhone',
          footer:
              'Local cache helps your files open faster. Clearing it leaves your Telegram files in place.',
          children: [
            IosRow(
              title: 'Local Cache',
              value: cache.isLoading
                  ? 'Scanning'
                  : formatFileSize(cache.totalSize),
              icon: CupertinoIcons.cube_box_fill,
              color: IosTint.storage,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const CacheStorageSettingsScreen(),
                ),
              ),
            ),
            IosRow(
              title: 'Free Up Space',
              icon: CupertinoIcons.device_phone_portrait,
              color: IosTint.freeUpSpace,
              onTap: () => context.push('/profile/free-up-space'),
            ),
          ],
        ),
      ],
    );
  }
}
