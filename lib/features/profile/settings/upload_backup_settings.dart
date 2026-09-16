part of '../settings_screen.dart';

class UploadSettingsScreen extends ConsumerWidget {
  const UploadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider).state;
    final auth = ref.watch(authControllerProvider);
    final thresholdMbStr =
        '${(auth.largeUploadThresholdBytes / (1024 * 1024)).toStringAsFixed(0)} MB';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Uploads'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl,
        ),
        children: [
          _SettingsPageHeader(
            icon: Icons.cloud_outlined,
            color: _accentUploads,
            title: 'Upload behavior',
            description:
                'Control when and how files are uploaded to Telegram so you stay within data and quota expectations.',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Network & Limits'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsSwitchTile(
                    title: 'Ask Before Large Uploads',
                    subtitle:
                        'Request confirmation when uploading files that exceed $thresholdMbStr.',
                    icon: Icons.help_outline_rounded,
                    iconColor: _accentUploads,
                    value: settings.askBeforeLargeUploads,
                    onChanged: ref
                        .read(appSettingsControllerProvider)
                        .setAskBeforeLargeUploads,
                  ),
                  _SettingsSwitchTile(
                    title: 'Upload on Mobile Data',
                    subtitle:
                        'Allow uploads over cellular data networks. When disabled, waits for Wi-Fi connection.',
                    icon: Icons.signal_cellular_alt_rounded,
                    iconColor: _accentUploads,
                    value: settings.uploadOnMobileData,
                    onChanged: ref
                        .read(appSettingsControllerProvider)
                        .setUploadOnMobileData,
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'File Handling'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsSwitchTile(
                    title: 'Auto-Rename Duplicate Files',
                    subtitle:
                        'Avoid overwriting existing files by appending a unique number (e.g., File (1).ext).',
                    icon: Icons.drive_file_rename_outline_rounded,
                    iconColor: _accentUploads,
                    value: settings.autoRenameDuplicates,
                    onChanged: ref
                        .read(appSettingsControllerProvider)
                        .setAutoRenameDuplicates,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider).state;
    final backup = ref.watch(galleryBackupControllerProvider);
    final controller = ref.read(appSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Backup'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl,
        ),
        children: [
          _SettingsPageHeader(
            icon: Icons.backup_outlined,
            color: _accentBackup,
            title: 'Gallery backup',
            description:
                'Backup on/off lives in the profile action sheet — this page tunes how scans discover and queue your media. Auto backups land in Auto > Media > Photos or Videos.',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Scan Behavior'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsSwitchTile(
                    title: 'Backup on Wi-Fi Only',
                    subtitle:
                        'Pause gallery backup on cellular data unless you explicitly allow it.',
                    icon: Icons.wifi_rounded,
                    iconColor: _accentBackup,
                    value: settings.galleryBackupWifiOnly,
                    onChanged: controller.setGalleryBackupWifiOnly,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsNumberTile(
                        title: 'Scan limit',
                        subtitle:
                            'Maximum recent media candidates inspected per scan.',
                        icon: Icons.image_search_rounded,
                        iconColor: _accentBackup,
                        value: settings.galleryBackupScanLimit,
                        min: 1,
                        max: 500,
                        step: 10,
                        onChanged: controller.setGalleryBackupScanLimit,
                      ),
                      const _SettingsInfoNote(
                        tone: _SettingsNoteTone.warning,
                        text:
                            'Increasing this makes each backup scan heavier. Very high values can slow startup, increase battery usage, and make media permission issues harder to debug.',
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsNumberTile(
                        title: 'Queue limit',
                        subtitle:
                            'Maximum gallery backup uploads allowed in the queue at once.',
                        icon: Icons.playlist_add_check_rounded,
                        iconColor: _accentBackup,
                        value: settings.galleryBackupQueueLimit,
                        min: 1,
                        max: 100,
                        step: 2,
                        onChanged: controller.setGalleryBackupQueueLimit,
                      ),
                      const _SettingsInfoNote(
                        tone: _SettingsNoteTone.warning,
                        text:
                            'Increasing this can enqueue many uploads at once. Very high values may drain battery, increase Telegram rate-limit risk, and make failures harder to recover.',
                      ),
                    ],
                  ),
                  _SettingsStrategyTile(
                    icon: Icons.tune_rounded,
                    iconColor: _accentBackup,
                    value: settings.galleryBackupIndexingStrategy,
                    onChanged: controller.setGalleryBackupIndexingStrategy,
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Actions'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsActionTile(
                    title: 'Scan now',
                    subtitle: settings.galleryBackupEnabled
                        ? 'Run an immediate scan using the current Backup settings.'
                        : 'Turn backup on from the profile action sheet before scanning.',
                    icon: Icons.travel_explore_rounded,
                    iconColor: _accentBackup,
                    enabled: settings.galleryBackupEnabled,
                    onTap: settings.galleryBackupEnabled
                        ? () => ref
                              .read(galleryBackupControllerProvider)
                              .scanNow(reason: 'settings_scan_now')
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Use the profile action sheet to turn backup on first.',
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Diagnostics'),
              _BackupDiagnosticsCard(
                diagnostics: backup.diagnostics,
                running: backup.running,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
