import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/notifications/upload_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/github_icon.dart';
import '../auth/auth_controller.dart';
import 'app_settings_controller.dart';
import 'cache_controller.dart';
import 'theme_controller.dart';
import 'widgets/telegram_status_card.dart';
import 'widgets/theme_picker_cards.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF131417),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131417),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.xxl),
        children: [
          _settingsSectionHeader('Categories'),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            iconColor: const Color(0xFF6E7C97),
            title: 'Upload Settings',
            subtitle: 'Manage upload limits, mobile network usage, & renaming',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const UploadSettingsScreen()),
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

          _settingsSectionHeader('Appearance'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ThemePickerCards(
              mode: ref.watch(themeControllerProvider).mode,
              onChanged: ref.read(themeControllerProvider).setMode,
            ),
          ),
          const SizedBox(height: 28),

          _settingsSectionHeader('Telegram Integration'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TelegramStatusCard(connected: auth.telegramConnected),
          ),
          const SizedBox(height: 28),

          _settingsSectionHeader('About Drive'),
          _InfoCard(
            iconWidget: GitHubIcon(size: 24, color: const Color(0xFF6E7C97)),
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

Widget _settingsSectionHeader(String label) {
  return Padding(
    padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6D7F99),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ==========================================
// Sub-Category Panels
// ==========================================

/// Shared section label used by [SettingsScreen] and its sub-pages so the
/// dedicated panels match the parent's visual rhythm exactly.
Widget _settingsSectionLabel(BuildContext context, String label) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxs,
      AppSpacing.sm,
      AppSpacing.xxs,
      AppSpacing.xs,
    ),
    child: Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );
}

/// Short paragraph that appears under a section label on a sub-page,
/// describing what the toggles below do. Mirrors the muted body style used
/// on the parent settings screen so the surface no longer feels empty.
Widget _settingsSectionIntro(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxs,
      0,
      AppSpacing.xxs,
      AppSpacing.sm,
    ),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    ),
  );
}

class UploadSettingsScreen extends ConsumerWidget {
  const UploadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider).state;
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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

class CacheStorageSettingsScreen extends ConsumerWidget {
  const CacheStorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Cache & Storage'),
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
            child: _settingsSectionLabel(context, 'Local Cache'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'TeleDrive keeps thumbnails and previews on this device so files open instantly. Clearing them only frees space — your files in Telegram are untouched.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Elegant usage dashboard
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: AppRadii.lgR,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cleaning_services_rounded,
                      color: scheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    cache.isLoading
                        ? 'Scanning...'
                        : _formatBytes(cache.totalSize),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Local Cache Size',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Maintenance'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Reclaim device storage by deleting cached previews. Telegram-hosted originals stay intact.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatActionTile(
            title: 'Free up space',
            subtitle: 'Delete local cache to reclaim storage.',
            onTap: () => context.push('/profile/free-up-space'),
          ),
        ],
      ),
    );
  }
}

class PrivacySecuritySettingsScreen extends ConsumerWidget {
  const PrivacySecuritySettingsScreen({super.key});

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
        title: const Text('Privacy & Security'),
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
            child: _settingsSectionLabel(context, 'Deletion'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Choose what happens when files are deleted, and recover items you removed by mistake.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Trash / safer delete',
            subtitle: settings.trashEnabled
                ? 'Deletes move to Trash first.'
                : 'Deletes are permanent immediately.',
            value: settings.trashEnabled,
            onChanged: ref.read(appSettingsControllerProvider).setTrashEnabled,
          ),
          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
          ),
          _FlatActionTile(
            title: 'Trash bin',
            subtitle: 'Restore items or delete them forever.',
            onTap: () => context.push('/settings/trash'),
          ),

          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Sharing'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Add a confirmation step before any link is created that anyone with the URL could open.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Confirm public share links',
            subtitle: 'Ask before creating links anyone can open.',
            value: settings.confirmPublicShares,
            onChanged: ref
                .read(appSettingsControllerProvider)
                .setConfirmPublicShares,
          ),

          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Sign Out'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Decide whether previews and thumbnails on this device should be wiped when you sign out. Files in Telegram are never affected.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatSwitchTile(
            title: 'Clear local cache on sign out',
            subtitle: 'Keeps Telegram files safe; only local cache is cleared.',
            value: settings.clearCacheOnSignOut,
            onChanged: ref
                .read(appSettingsControllerProvider)
                .setClearCacheOnSignOut,
          ),
        ],
      ),
    );
  }
}

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

// ==========================================
// Reusable Premium Design UI Components
// ==========================================

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.statusText,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (statusText != null) ...[
              Text(
                statusText!,
                style: const TextStyle(
                  color: Color(0xFF6D7F99),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF5E626B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 1,
      thickness: 1,
      indent: 64, // Align with the start of title/subtitle text
      endIndent: 0,
    );
  }
}

class _FlatSwitchTile extends StatelessWidget {
  const _FlatSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatActionTile extends StatelessWidget {
  const _FlatActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.iconWidget,
    this.onTap,
  });

  final Widget iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 24, height: 24, child: Center(child: iconWidget)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}
