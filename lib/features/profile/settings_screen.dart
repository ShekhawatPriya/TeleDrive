import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/network/backend_resolver.dart';
import '../../core/notifications/upload_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
import 'app_settings_controller.dart';
import 'cache_controller.dart';
import 'gallery_backup_controller.dart';
import 'theme_controller.dart';
import 'widgets/theme_picker_cards.dart';

part 'settings/settings_helpers.dart';
part 'settings/server_connection_settings.dart';
part 'settings/upload_backup_settings.dart';
part 'settings/cache_privacy_settings.dart';
part 'settings/notification_settings.dart';
part 'settings/settings_menu_tiles.dart';
part 'settings/settings_form_tiles.dart';
part 'settings/backup_diagnostics_card.dart';
part 'settings/app_updates_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xxl,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Connectivity'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [_ServerConnectionSettingsTile()],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Uploads & Backup'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsMenuTile(
                    icon: Icons.cloud_outlined,
                    iconColor: _accentUploads,
                    title: 'Uploads',
                    subtitle: 'Limits, mobile data, and duplicate renaming',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UploadSettingsScreen(),
                      ),
                    ),
                  ),
                  _SettingsMenuTile(
                    icon: Icons.backup_outlined,
                    iconColor: _accentBackup,
                    title: 'Backup',
                    subtitle: 'Gallery backup scans and queue behavior',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BackupSettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Storage & Privacy'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsMenuTile(
                    icon: Icons.cleaning_services_outlined,
                    iconColor: _accentCache,
                    title: 'Cache & Storage',
                    subtitle: 'Reclaim space from the local file cache',
                    trailing: AnimatedSwitcher(
                      duration: AppDurations.medium2,
                      switchInCurve: AppEasing.standard,
                      switchOutCurve: AppEasing.standard,
                      child: Text(
                        cache.isLoading
                            ? 'Scanning...'
                            : _formatBytes(cache.totalSize),
                        key: ValueKey(
                          cache.isLoading ? 'scanning' : '${cache.totalSize}',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CacheStorageSettingsScreen(),
                      ),
                    ),
                  ),
                  _SettingsMenuTile(
                    icon: Icons.shield_outlined,
                    iconColor: _accentPrivacy,
                    title: 'Privacy & Security',
                    subtitle: 'Trash bin, share links, and sign-out cache',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacySecuritySettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Alerts & Updates'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsMenuTile(
                    icon: Icons.notifications_none_outlined,
                    iconColor: _accentAlerts,
                    title: 'Notifications',
                    subtitle: 'Alerts for completed or failed uploads',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsSettingsScreen(),
                      ),
                    ),
                  ),
                  // APK self-update is Android-only; iOS updates ship via
                  // the App Store.
                  if (Platform.isAndroid) _AppUpdatesSettingsTile(),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ThemePickerCards(
                  mode: ref.watch(themeControllerProvider).mode,
                  onChanged: ref.read(themeControllerProvider).setMode,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'About'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsMenuTile(
                    icon: Icons.workspaces_outline,
                    iconColor: _accentProject,
                    title: 'Project',
                    subtitle: 'Open source, changelog, and about TeleDrive',
                    onTap: () => context.push('/settings/project'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'TeleDrive - A DevsDoCode Project',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
