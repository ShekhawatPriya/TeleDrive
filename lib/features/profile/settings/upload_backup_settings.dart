part of '../settings_screen.dart';

class UploadSettingsScreen extends ConsumerWidget {
  const UploadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider).state;
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final thresholdMbStr =
        '${(auth.largeUploadThresholdBytes / (1024 * 1024)).toStringAsFixed(0)} MB';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Upload Settings'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Network & Limits'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Control when and how files are uploaded to Telegram so you stay within data and quota expectations.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Ask Before Large Uploads',
            subtitle:
                'Request confirmation when uploading files that exceed $thresholdMbStr.',
            value: settings.askBeforeLargeUploads,
            onChanged: ref
                .read(appSettingsControllerProvider)
                .setAskBeforeLargeUploads,
          ),
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
          ),
          _FlatSwitchTile(
            title: 'Upload on Mobile Data',
            subtitle:
                'Allow uploads over cellular data networks. When disabled, waits for Wi-Fi connection.',
            value: settings.uploadOnMobileData,
            onChanged: ref
                .read(appSettingsControllerProvider)
                .setUploadOnMobileData,
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'File Handling'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'How TeleDrive resolves naming conflicts when uploading files that share a name.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Auto-Rename Duplicate Files',
            subtitle:
                'Avoid overwriting existing files by appending a unique number (e.g., File (1).ext).',
            value: settings.autoRenameDuplicates,
            onChanged: ref
                .read(appSettingsControllerProvider)
                .setAutoRenameDuplicates,
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Gallery Backup'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'The profile action sheet controls backup on/off. This page only configures scans. File transfers are handled locally on this device through TDLib, and Auto backups go to Auto > Media > Photos or Videos.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Backup on Wi-Fi Only',
            subtitle:
                'Pause gallery backup on cellular data unless you explicitly allow it.',
            value: settings.galleryBackupWifiOnly,
            onChanged: controller.setGalleryBackupWifiOnly,
          ),
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
          ),
          _FlatNumberTile(
            title: 'Scan limit',
            subtitle: 'Maximum recent media candidates inspected per scan.',
            value: settings.galleryBackupScanLimit,
            min: 1,
            max: 500,
            step: 10,
            onChanged: controller.setGalleryBackupScanLimit,
          ),
          _WarningText(
            text:
                'Increasing this makes each backup scan heavier. Very high values can slow startup, increase battery usage, and make media permission issues harder to debug.',
          ),
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
          ),
          _FlatNumberTile(
            title: 'Queue limit',
            subtitle:
                'Maximum gallery backup uploads allowed in the queue at once.',
            value: settings.galleryBackupQueueLimit,
            min: 1,
            max: 100,
            step: 2,
            onChanged: controller.setGalleryBackupQueueLimit,
          ),
          _WarningText(
            text:
                'Increasing this can enqueue many uploads at once. Very high values may drain battery, increase Telegram rate-limit risk, and make failures harder to recover.',
          ),
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
          ),
          _FlatStrategyTile(
            value: settings.galleryBackupIndexingStrategy,
            onChanged: controller.setGalleryBackupIndexingStrategy,
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Actions'),
          ),
          _FlatActionTile(
            title: 'Scan now',
            subtitle: settings.galleryBackupEnabled
                ? 'Run an immediate scan using the current Backup settings.'
                : 'Turn backup on from the profile action sheet before scanning.',
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
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Diagnostics'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _BackupDiagnosticsCard(
              diagnostics: backup.diagnostics,
              running: backup.running,
            ),
          ),
        ],
      ),
    );
  }
}
