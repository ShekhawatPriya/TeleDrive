part of '../settings_screen.dart';

class _AppUpdatesSettingsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.system_update_alt_rounded,
      iconColor: const Color(0xFF5C8AA8),
      title: 'App Updates',
      subtitle: 'Check for the latest TeleDrive APK release',
      onTap: () => context.push('/settings/app-update'),
    );
  }
}
