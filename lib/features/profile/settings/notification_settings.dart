part of '../settings_screen.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  Future<void> _setNotificationToggle(
    BuildContext context,
    WidgetRef ref, {
    bool? complete,
    bool? failed,
  }) async {
    if (complete == true || failed == true) {
      final ok = await ref
          .read(uploadNotificationServiceProvider)
          .requestPermission();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications are disabled.')),
        );
        return;
      }
    }
    final controller = ref.read(appSettingsControllerProvider);
    if (complete != null) {
      await controller.setUploadCompletedAlerts(complete);
    }
    if (failed != null) {
      await controller.setUploadFailedAlerts(failed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider).state;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications'),
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
            child: _settingsSectionLabel(context, 'Upload Alerts'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Choose which upload events should trigger a system notification on this device.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Upload completed alerts',
            subtitle: 'Show a local alert when uploads finish.',
            value: settings.uploadCompletedAlerts,
            onChanged: (value) =>
                _setNotificationToggle(context, ref, complete: value),
          ),
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
          ),
          _FlatSwitchTile(
            title: 'Upload failed alerts',
            subtitle: 'Show a local alert when uploads fail.',
            value: settings.uploadFailedAlerts,
            onChanged: (value) =>
                _setNotificationToggle(context, ref, failed: value),
          ),
        ],
      ),
    );
  }
}
