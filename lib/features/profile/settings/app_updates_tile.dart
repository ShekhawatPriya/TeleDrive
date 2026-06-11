part of '../settings_screen.dart';

class _AppUpdatesSettingsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsMenuTile(
      icon: Icons.system_update_alt_rounded,
      iconColor: _accentUpdates,
      title: 'App Updates',
      subtitle: 'Check for the latest APK release',
      onTap: () => context.push('/settings/app-update'),
    );
  }
}
