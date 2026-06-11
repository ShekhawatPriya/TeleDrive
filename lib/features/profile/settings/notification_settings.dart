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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
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
          const _StaggeredEntrance(
            index: 0,
            child: _SettingsPageHeader(
              icon: Icons.notifications_none_outlined,
              color: _accentAlerts,
              title: 'Upload alerts',
              description:
                  'Choose which upload events should trigger a system notification on this device.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StaggeredEntrance(
            index: 1,
            child: _SettingsGroupCard(
              dividerIndent: 72,
              children: [
                _SettingsSwitchTile(
                  title: 'Upload completed alerts',
                  subtitle: 'Show a local alert when uploads finish.',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: _accentAlerts,
                  value: settings.uploadCompletedAlerts,
                  onChanged: (value) =>
                      _setNotificationToggle(context, ref, complete: value),
                ),
                _SettingsSwitchTile(
                  title: 'Upload failed alerts',
                  subtitle: 'Show a local alert when uploads fail.',
                  icon: Icons.error_outline_rounded,
                  iconColor: _accentAlerts,
                  value: settings.uploadFailedAlerts,
                  onChanged: (value) =>
                      _setNotificationToggle(context, ref, failed: value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
