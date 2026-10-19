import 'package:flutter/cupertino.dart';
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
    final data = summary;
    return IosPage(
      title: 'Telegram Drive',
      compact: true,
      onRefresh: onRefresh,
      onBack: () => context.canPop() ? context.pop() : context.go('/drive'),
      children: [
        IosSettingsIntro(
          icon: CupertinoIcons.tray_2_fill,
          color: IosTint.telegramDrive,
          title: 'Telegram Drive',
          description:
              'See how your library uses your Telegram account and what TeleDrive keeps on this iPhone.',
          onLearnMore: () => context.push('/privacy'),
        ),
        if (data == null) ...[
          if (error == null)
            const Padding(
              padding: EdgeInsets.only(bottom: IosPageMetrics.groupSpacing),
              child: CupertinoActivityIndicator(),
            )
          else
            IosGroup(
              footer: error,
              children: [
                IosRow(
                  title: 'Try Again',
                  action: true,
                  trailing: const SizedBox.shrink(),
                  onTap: onRefresh,
                ),
              ],
            ),
        ] else ...[
          if (error != null)
            const IosNote(
              'Showing your last loaded storage usage. Pull down to refresh.',
            ),
          IosGroup(
            title: 'Summary',
            footer: 'Telegram doesn’t limit how much you can store.',
            children: [
              _StorageBar(summary: data),
              IosRow(title: 'Used', value: formatStorageSize(data.totalBytes)),
              IosRow(title: 'Files', value: '${data.totalFiles}'),
            ],
          ),
          IosGroup(
            title: 'In Telegram',
            children: [
              IosRow(
                title: 'Photos',
                subtitle: '${data.imageCount} items',
                value: formatStorageSize(data.imageBytes),
                icon: CupertinoIcons.photo_fill,
                color: IosTint.photos,
              ),
              IosRow(
                title: 'Videos',
                subtitle: '${data.videoCount} items',
                value: formatStorageSize(data.videoBytes),
                icon: CupertinoIcons.videocam_fill,
                color: IosTint.videos,
              ),
              IosRow(
                title: 'Documents',
                subtitle: '${data.documentCount} items',
                value: formatStorageSize(data.documentBytes),
                icon: CupertinoIcons.doc_fill,
                color: IosTint.documents,
              ),
              IosRow(
                title: 'Audio',
                subtitle: '${data.audioCount} items',
                value: formatStorageSize(data.audioBytes),
                icon: CupertinoIcons.music_note,
                color: IosTint.audio,
              ),
              IosRow(
                title: 'Other Files',
                subtitle: '${data.otherCount} items',
                value: formatStorageSize(data.otherBytes),
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
                  : formatStorageSize(cache.totalSize),
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

/// iPhone Storage's segmented bar: one track split by media kind in the same
/// tints as the rows below, with a legend. Real totals only; an empty library
/// shows an empty track.
class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.summary});
  final StorageSummary summary;

  @override
  Widget build(BuildContext context) {
    final segments = [
      ('Photos', summary.imageBytes, IosTint.photos),
      ('Videos', summary.videoBytes, IosTint.videos),
      ('Documents', summary.documentBytes, IosTint.documents),
      ('Audio', summary.audioBytes, IosTint.audio),
      ('Other', summary.otherBytes, IosTint.other),
    ].where((s) => s.$2 > 0).toList();
    final total = segments.fold<int>(0, (sum, s) => sum + s.$2);
    final track = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Semantics(
      label: total == 0
          ? 'No storage used'
          : segments
                .map((s) => '${s.$1} ${formatStorageSize(s.$2)}')
                .join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 22,
                  child: ColoredBox(
                    color: track,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, s) in segments.indexed) ...[
                          if (i > 0) const SizedBox(width: 1.5),
                          Expanded(
                            // At least a sliver so tiny kinds stay visible.
                            flex: (s.$2 / total * 1000).round().clamp(8, 1000),
                            child: ColoredBox(
                              color: CupertinoDynamicColor.resolve(
                                s.$3,
                                context,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (segments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final s in segments)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: CupertinoDynamicColor.resolve(
                                s.$3,
                                context,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            s.$1,
                            style: TextStyle(fontSize: 13, color: secondary),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
