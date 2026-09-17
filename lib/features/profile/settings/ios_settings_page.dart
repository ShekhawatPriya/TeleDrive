part of '../settings_screen.dart';

Widget _iosSettings(BuildContext context, WidgetRef ref) {
  final cache = ref.watch(cacheControllerProvider).state;
  final mode = ref.watch(themeControllerProvider).mode;
  final status = ref.watch(backendResolverProvider).status;
  void open(Widget page) => Navigator.of(
    context,
  ).push(CupertinoPageRoute<void>(builder: (_) => page));
  return IosPage(
    title: 'Settings',
    compact: true,
    children: [
      IosGroup(
        children: [
          IosRow(
            title: 'Server Connection',
            icon: CupertinoIcons.antenna_radiowaves_left_right,
            value: switch (status) {
              BackendStatus.connected => 'Connected',
              BackendStatus.resolving => 'Searching',
              _ => 'Offline',
            },
            onTap: () => open(const ServerConnectionSettingsScreen()),
          ),
        ],
      ),
      IosGroup(
        title: 'Library',
        children: [
          IosRow(
            title: 'Uploads',
            icon: CupertinoIcons.arrow_up_doc_fill,
            color: CupertinoColors.systemBlue,
            onTap: () => open(const UploadSettingsScreen()),
          ),
          IosRow(
            title: 'Photo Backup',
            icon: CupertinoIcons.cloud_upload_fill,
            color: CupertinoColors.systemIndigo,
            onTap: () => open(const BackupSettingsScreen()),
          ),
          IosRow(
            title: 'Cache & Storage',
            icon: CupertinoIcons.cube_box_fill,
            color: CupertinoColors.systemOrange,
            value: cache.isLoading ? 'Scanning' : _formatBytes(cache.totalSize),
            onTap: () => open(const CacheStorageSettingsScreen()),
          ),
        ],
      ),
      IosGroup(
        children: [
          IosRow(
            title: 'Privacy & Security',
            icon: CupertinoIcons.hand_raised_fill,
            color: CupertinoColors.systemBlue,
            onTap: () => open(const PrivacySecuritySettingsScreen()),
          ),
          IosRow(
            title: 'Notifications',
            icon: CupertinoIcons.bell_fill,
            color: CupertinoColors.systemRed,
            onTap: () => open(const NotificationsSettingsScreen()),
          ),
        ],
      ),
      IosAppearancePicker(
        mode: mode,
        onChanged: ref.read(themeControllerProvider).setMode,
      ),
      IosGroup(
        children: [
          IosRow(
            title: 'About TeleDrive',
            icon: CupertinoIcons.info_circle_fill,
            color: CupertinoColors.systemGrey,
            onTap: () => context.push('/settings/project'),
          ),
        ],
      ),
      const IosNote('TeleDrive · A DevsDoCode Project'),
    ],
  );
}

/// Retains each settings controller and form, replacing Material page chrome.
class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.appBar, required this.body});
  final AppBar appBar;
  final Widget body;
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS)
      return Scaffold(appBar: appBar, body: body);
    final list = body;
    if (list is ListView && list.childrenDelegate is SliverChildListDelegate) {
      return IosPage(
        title: (appBar.title as Text).data ?? 'Settings',
        compact: true,
        horizontalPadding: 0,
        children: (list.childrenDelegate as SliverChildListDelegate).children,
      );
    }
    return Scaffold(appBar: appBar, body: body);
  }
}
