import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/notifications/upload_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/social_icons.dart';
import '../auth/auth_controller.dart';
import 'app_settings_controller.dart';
import 'cache_controller.dart';
import 'gallery_backup_controller.dart';
import 'theme_controller.dart';
import 'widgets/telegram_status_card.dart';
import 'widgets/theme_picker_cards.dart';

part 'settings/settings_helpers.dart';
part 'settings/upload_backup_settings.dart';
part 'settings/cache_privacy_settings.dart';
part 'settings/notification_settings.dart';
part 'settings/settings_menu_tiles.dart';
part 'settings/settings_form_tiles.dart';
part 'settings/backup_diagnostics_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.xxl),
        children: [
          _settingsSectionHeader(context, 'Categories'),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            iconColor: const Color(0xFF6E7C97),
            title: 'Upload Settings',
            subtitle: 'Manage manual upload limits, network usage, & renaming',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const UploadSettingsScreen()),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.backup_outlined,
            iconColor: const Color(0xFF4C8F87),
            title: 'Backup',
            subtitle:
                'Configure gallery backup scans and queue behavior',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const BackupSettingsScreen()),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            iconColor: const Color(0xFFDCA15D),
            title: 'Cache & Storage Settings',
            subtitle: 'Reclaim phone storage and clean local file cache',
            statusText: cache.isLoading
                ? 'Scanning...'
                : _formatBytes(cache.totalSize),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const CacheStorageSettingsScreen(),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF8BA698),
            title: 'Privacy & Security Settings',
            subtitle:
                'Configure trash bin, share link permissions, & sign out cache',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const PrivacySecuritySettingsScreen(),
              ),
            ),
          ),
          const _SettingsDivider(),
          _SettingsTile(
            icon: Icons.notifications_none_outlined,
            iconColor: const Color(0xFFC393B5),
            title: 'Notifications Settings',
            subtitle: 'Set up push alerts for completed or failed uploads',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const NotificationsSettingsScreen(),
              ),
            ),
          ),
          const _SettingsDivider(),
          const SizedBox(height: 24),
          _settingsSectionHeader(context, 'Appearance'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ThemePickerCards(
              mode: ref.watch(themeControllerProvider).mode,
              onChanged: ref.read(themeControllerProvider).setMode,
            ),
          ),
          const SizedBox(height: 28),
          _settingsSectionHeader(context, 'Telegram Integration'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TelegramStatusCard(connected: auth.telegramConnected),
          ),
          const SizedBox(height: 28),
          _settingsSectionHeader(context, 'About Drive'),
          _InfoCard(
            iconWidget: GitHubIcon(size: 24, color: scheme.onSurfaceVariant),
            title: 'GitHub',
            subtitle: 'Open Source Project',
            onTap: AppConfig.openRepository,
          ),
          const SizedBox(height: AppSpacing.xxl),
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
