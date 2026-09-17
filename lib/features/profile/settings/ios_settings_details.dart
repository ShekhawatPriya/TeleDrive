part of '../settings_screen.dart';

Widget _iosToggle(String title, bool value, ValueChanged<bool> onChanged) =>
    IosRow(
      title: title,
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );

Widget _iosUploads(BuildContext context, WidgetRef ref, String threshold) {
  final settings = ref.watch(appSettingsControllerProvider).state;
  final controller = ref.read(appSettingsControllerProvider);
  return IosPage(
    title: 'Uploads',
    compact: true,
    children: [
      const IosSettingsIntro(
        icon: CupertinoIcons.arrow_up_doc_fill,
        color: CupertinoColors.systemBlue,
        title: 'Uploads',
        description:
            'Choose how TeleDrive uploads your files and uses mobile data.',
      ),
      IosGroup(
        title: 'Network',
        footer: 'When mobile data is off, uploads wait for Wi-Fi.',
        children: [
          _iosToggle(
            'Use Mobile Data',
            settings.uploadOnMobileData,
            controller.setUploadOnMobileData,
          ),
        ],
      ),
      IosGroup(
        title: 'Large Files',
        footer:
            'Ask for confirmation before uploading files larger than $threshold.',
        children: [
          _iosToggle(
            'Confirm Large Uploads',
            settings.askBeforeLargeUploads,
            controller.setAskBeforeLargeUploads,
          ),
        ],
      ),
      IosGroup(
        title: 'Duplicate Files',
        footer: 'Add a number to duplicate filenames, such as Photo (1).jpg.',
        children: [
          _iosToggle(
            'Rename Duplicates',
            settings.autoRenameDuplicates,
            controller.setAutoRenameDuplicates,
          ),
        ],
      ),
    ],
  );
}

Widget _iosBackup(BuildContext context, WidgetRef ref) {
  final settings = ref.watch(appSettingsControllerProvider).state;
  final controller = ref.read(appSettingsControllerProvider);
  final backup = ref.watch(galleryBackupControllerProvider);
  return IosPage(
    title: 'Photo Backup',
    compact: true,
    children: [
      const IosSettingsIntro(
        icon: CupertinoIcons.cloud_upload_fill,
        color: CupertinoColors.systemIndigo,
        title: 'Photo Backup',
        description:
            'Save photos and videos from your photo library to your Telegram account.',
      ),
      IosGroup(
        footer: 'Backups are saved in Auto › Media › Photos or Videos.',
        children: [
          _iosToggle(
            'Photo Backup',
            settings.galleryBackupEnabled,
            controller.setGalleryBackupEnabled,
          ),
          _iosToggle(
            'Wi-Fi Only',
            settings.galleryBackupWifiOnly,
            controller.setGalleryBackupWifiOnly,
          ),
        ],
      ),
      IosGroup(
        title: 'Scan Limits',
        footer:
            'Higher limits may use more battery and queue more uploads at once.',
        children: [
          _IosLimitRow(
            title: 'Items per Scan',
            value: settings.galleryBackupScanLimit,
            min: 1,
            max: 500,
            step: 10,
            onChanged: controller.setGalleryBackupScanLimit,
          ),
          _IosLimitRow(
            title: 'Queued Uploads',
            value: settings.galleryBackupQueueLimit,
            min: 1,
            max: 100,
            step: 2,
            onChanged: controller.setGalleryBackupQueueLimit,
          ),
        ],
      ),
      IosGroup(
        footer: settings.galleryBackupEnabled
            ? null
            : 'Turn on Photo Backup to scan your library.',
        children: [
          IosRow(
            title: backup.running ? 'Scanning…' : 'Scan Now',
            action: true,
            enabled: settings.galleryBackupEnabled && !backup.running,
            trailing: backup.running
                ? const CupertinoActivityIndicator()
                : const SizedBox.shrink(),
            onTap: settings.galleryBackupEnabled && !backup.running
                ? () => backup.scanNow(reason: 'settings_scan_now')
                : null,
          ),
          IosRow(
            title: 'Scan Report',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => const _IosScanReport()),
            ),
          ),
        ],
      ),
    ],
  );
}

class _IosLimitRow extends StatelessWidget {
  const _IosLimitRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });
  final String title;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max))
              : null,
          child: Icon(
            CupertinoIcons.minus,
            size: 18,
            semanticLabel: 'Decrease $title',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Semantics(
            value: '$value',
            label: title,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 17, color: scheme.onSurface),
            ),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max))
              : null,
          child: Icon(
            CupertinoIcons.plus,
            size: 18,
            semanticLabel: 'Increase $title',
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            title,
            style: TextStyle(fontSize: 17, color: scheme.onSurface),
          );
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(17) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: controls,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _IosScanReport extends ConsumerWidget {
  const _IosScanReport();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(galleryBackupControllerProvider);
    final d = backup.diagnostics;
    String time(DateTime? date) => date == null
        ? 'Not yet'
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(date.toLocal()));
    return IosPage(
      title: 'Scan Report',
      compact: true,
      children: [
        IosGroup(
          children: [
            IosRow(
              title: 'Status',
              value: backup.running ? 'Scanning' : 'Idle',
            ),
            IosRow(title: 'Started', value: time(d.lastScanStartedAt)),
            IosRow(title: 'Completed', value: time(d.lastScanCompletedAt)),
            IosRow(
              title: 'Duration',
              value: d.scanDuration == null
                  ? '—'
                  : '${d.scanDuration!.inMilliseconds} ms',
            ),
          ],
        ),
        IosGroup(
          title: 'Photo Library',
          children: [
            IosRow(title: 'Items Found', value: '${d.mergedCandidates}'),
            IosRow(
              title: 'Already Uploaded',
              value: '${d.skippedAlreadyUploaded}',
            ),
            IosRow(title: 'Already Queued', value: '${d.skippedAlreadyQueued}'),
            IosRow(title: 'No Permission', value: '${d.skippedPermission}'),
            IosRow(title: 'Unavailable Items', value: '${d.skippedInvalid}'),
            IosRow(title: 'Added to Queue', value: '${d.enqueued}'),
            IosRow(
              title: 'Last Upload',
              value: time(d.lastUploadCompleteMarker),
            ),
          ],
        ),
        if (d.lastError != null || d.lastEnqueueError != null)
          IosGroup(
            title: 'Latest Issue',
            children: [
              if (d.lastError != null)
                IosRow(title: 'Scan', subtitle: d.lastError),
              if (d.lastEnqueueError != null)
                IosRow(title: 'Upload Queue', subtitle: d.lastEnqueueError),
            ],
          ),
        for (final note in d.notes) IosNote(note),
      ],
    );
  }
}

Widget _iosCache(BuildContext context, WidgetRef ref) {
  final cache = ref.watch(cacheControllerProvider).state;
  return IosPage(
    title: 'Cache & Storage',
    compact: true,
    children: [
      IosSettingsIntro(
        icon: CupertinoIcons.cube_box_fill,
        color: CupertinoColors.systemOrange,
        title: cache.isLoading ? 'Calculating…' : _formatBytes(cache.totalSize),
        description:
            'Used on this iPhone for cached files and uploads. Your files in Telegram are stored separately.',
      ),
      IosGroup(
        title: 'On This iPhone',
        children: [
          IosRow(title: 'Thumbnails', value: _formatBytes(cache.thumbnailSize)),
          IosRow(title: 'Previews', value: _formatBytes(cache.previewSize)),
          IosRow(title: 'Originals', value: _formatBytes(cache.originalSize)),
          IosRow(
            title: 'Upload Staging',
            value: _formatBytes(cache.uploadStagingSize),
          ),
        ],
      ),
      IosGroup(
        footer:
            'Review backed-up photos and videos before removing their copies from this iPhone.',
        children: [
          IosRow(
            title: 'Free Up Space',
            icon: CupertinoIcons.device_phone_portrait,
            color: CupertinoColors.systemGreen,
            onTap: () => context.push('/profile/free-up-space'),
          ),
        ],
      ),
    ],
  );
}

Widget _iosPrivacy(BuildContext context, WidgetRef ref) {
  final settings = ref.watch(appSettingsControllerProvider).state;
  final controller = ref.read(appSettingsControllerProvider);
  return IosPage(
    title: 'Privacy & Security',
    compact: true,
    children: [
      const IosSettingsIntro(
        icon: CupertinoIcons.hand_raised_fill,
        color: CupertinoColors.systemBlue,
        title: 'Privacy & Security',
        description:
            'Manage deleted files, public links, and the data kept on this iPhone.',
      ),
      IosGroup(
        title: 'Deleted Files',
        footer: settings.trashEnabled
            ? 'Deleted files go to Trash so you can restore them.'
            : 'Files are deleted permanently when Trash is off.',
        children: [
          _iosToggle(
            'Use Trash',
            settings.trashEnabled,
            controller.setTrashEnabled,
          ),
          IosRow(
            title: 'Recently Deleted',
            onTap: () => context.push('/settings/trash'),
          ),
        ],
      ),
      IosGroup(
        title: 'Sharing',
        footer: 'Ask before creating a link that anyone can open.',
        children: [
          _iosToggle(
            'Confirm Public Links',
            settings.confirmPublicShares,
            controller.setConfirmPublicShares,
          ),
        ],
      ),
      IosGroup(
        title: 'Signing Out',
        footer:
            'Remove cached files from this device when you sign out. Files in Telegram are kept.',
        children: [
          _iosToggle(
            'Clear Local Cache',
            settings.clearCacheOnSignOut,
            controller.setClearCacheOnSignOut,
          ),
        ],
      ),
    ],
  );
}

Widget _iosNotifications(
  BuildContext context,
  WidgetRef ref,
  ValueChanged<bool> onComplete,
  ValueChanged<bool> onFailed,
) {
  final settings = ref.watch(appSettingsControllerProvider).state;
  return IosPage(
    title: 'Notifications',
    compact: true,
    children: [
      const IosSettingsIntro(
        icon: CupertinoIcons.bell_fill,
        color: CupertinoColors.systemRed,
        title: 'Notifications',
        description: 'Choose which upload events send an alert to this iPhone.',
      ),
      IosGroup(
        title: 'Upload Alerts',
        footer: 'Notifications also need permission in your iPhone’s Settings.',
        children: [
          _iosToggle(
            'Upload Completed',
            settings.uploadCompletedAlerts,
            onComplete,
          ),
          _iosToggle('Upload Failed', settings.uploadFailedAlerts, onFailed),
        ],
      ),
    ],
  );
}
