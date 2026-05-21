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
    final settings = ref.watch(appSettingsControllerProvider).state;
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          // Section header/title
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.xxs),
            child: Text(
              'Categories',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Upload Settings Category Card
          _CategoryNavCard(
            icon: Icons.cloud_upload_outlined,
            iconColor: Colors.indigo,
            title: 'Upload Settings',
            subtitle: 'Manage upload limits, mobile network usage, & renaming',
            statusText: settings.uploadOnMobileData ? 'Mobile Data & Wi-Fi' : 'Wi-Fi Only',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const UploadSettingsScreen()),
            ),
          ),

          // Cache & Storage Category Card
          _CategoryNavCard(
            icon: Icons.cleaning_services_rounded,
            iconColor: Colors.amber[700]!,
            title: 'Cache & Storage Settings',
            subtitle: 'Reclaim phone storage and clean local file cache',
            statusText: cache.isLoading ? 'Scanning...' : _formatBytes(cache.totalSize),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const CacheStorageSettingsScreen()),
            ),
          ),

          // Privacy & Security Category Card
          _CategoryNavCard(
            icon: Icons.security_rounded,
            iconColor: Colors.teal,
            title: 'Privacy & Security Settings',
            subtitle: 'Configure trash bin, share link permissions, & sign out cache',
            statusText: settings.trashEnabled ? 'Trash Active' : 'Direct Delete',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const PrivacySecuritySettingsScreen()),
            ),
          ),

          // Notifications Category Card
          _CategoryNavCard(
            icon: Icons.notifications_none_rounded,
            iconColor: Colors.purple,
            title: 'Notifications Settings',
            subtitle: 'Set up push alerts for completed or failed uploads',
            statusText: _getNotificationStatusText(settings),
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const NotificationsSettingsScreen()),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Appearance Section (Flat Entry)
          _sectionLabel(context, 'Appearance'),
          const SizedBox(height: AppSpacing.xs),
          ThemePickerCards(
            mode: ref.watch(themeControllerProvider).mode,
            onChanged: ref.read(themeControllerProvider).setMode,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Telegram Integration Section (Flat Entry)
          _sectionLabel(context, 'Telegram Integration'),
          const SizedBox(height: AppSpacing.xs),
          TelegramStatusCard(
            connected: auth.telegramConnected,
            telegramId: user?.telegramId,
          ),

          const SizedBox(height: AppSpacing.lg),

          // About Section (Flat Entry)
          _sectionLabel(context, 'About Drive'),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.tag_rounded,
                  title: 'v${AppConfig.appVersion}',
                  subtitle: 'Version',
                  iconColor: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _InfoCard(
                  iconWidget: GitHubIcon(size: 18, color: scheme.onSurface),
                  title: 'GitHub',
                  subtitle: 'Open Source',
                  onTap: AppConfig.openRepository,
                ),
              ),
            ],
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

  Widget _sectionLabel(BuildContext context, String label) {
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

  String _getNotificationStatusText(AppSettingsState settings) {
    if (settings.uploadCompletedAlerts && settings.uploadFailedAlerts) {
      return 'All Alerts';
    } else if (settings.uploadCompletedAlerts) {
      return 'Completed Only';
    } else if (settings.uploadFailedAlerts) {
      return 'Failed Only';
    } else {
      return 'Muted';
    }
  }
}

// ==========================================
// Sub-Category Panels
// ==========================================

class UploadSettingsScreen extends ConsumerWidget {
  const UploadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider).state;
    final auth = ref.watch(authControllerProvider);
    final thresholdMbStr = '${(auth.largeUploadThresholdBytes / (1024 * 1024)).toStringAsFixed(0)} MB';

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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _PremiumSwitchTile(
            icon: Icons.priority_high_rounded,
            iconColor: Colors.indigo,
            title: 'Ask before large uploads',
            subtitle: 'Confirm before uploading files larger than $thresholdMbStr.',
            value: settings.askBeforeLargeUploads,
            onChanged: ref.read(appSettingsControllerProvider).setAskBeforeLargeUploads,
          ),
          _PremiumSwitchTile(
            icon: Icons.network_cell_rounded,
            iconColor: Colors.indigo,
            title: 'Upload on mobile data',
            subtitle: 'When off, uploads wait for Wi-Fi automatically.',
            value: settings.uploadOnMobileData,
            onChanged: ref.read(appSettingsControllerProvider).setUploadOnMobileData,
          ),
          _PremiumSwitchTile(
            icon: Icons.drive_file_rename_outline_rounded,
            iconColor: Colors.indigo,
            title: 'Rename duplicate files automatically',
            subtitle: 'Use clean names like File (1).ext on upload.',
            value: settings.autoRenameDuplicates,
            onChanged: ref.read(appSettingsControllerProvider).setAutoRenameDuplicates,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Elegant usage dashboard
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.15),
                  scheme.primaryContainer.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadii.xlR,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cleaning_services_rounded,
                  color: scheme.primary,
                  size: 44,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  cache.isLoading ? 'Scanning...' : _formatBytes(cache.totalSize),
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
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Temporary files, thumbnails, and preview data cached locally. Clearing them will free up device storage without deleting files from Telegram.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          _PremiumActionTile(
            icon: Icons.cleaning_services_rounded,
            iconColor: Colors.amber[700]!,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _PremiumSwitchTile(
            icon: Icons.delete_sweep_outlined,
            iconColor: Colors.teal,
            title: 'Trash / safer delete',
            subtitle: settings.trashEnabled ? 'Deletes move to Trash first.' : 'Deletes are permanent immediately.',
            value: settings.trashEnabled,
            onChanged: ref.read(appSettingsControllerProvider).setTrashEnabled,
          ),
          _PremiumActionTile(
            icon: Icons.restore_from_trash_outlined,
            iconColor: Colors.teal,
            title: 'Trash bin',
            subtitle: 'Restore items or delete them forever.',
            onTap: () => context.push('/settings/trash'),
          ),
          _PremiumSwitchTile(
            icon: Icons.link_rounded,
            iconColor: Colors.teal,
            title: 'Confirm public share links',
            subtitle: 'Ask before creating links anyone can open.',
            value: settings.confirmPublicShares,
            onChanged: ref.read(appSettingsControllerProvider).setConfirmPublicShares,
          ),
          _PremiumSwitchTile(
            icon: Icons.logout_rounded,
            iconColor: Colors.teal,
            title: 'Clear local cache on sign out',
            subtitle: 'Keeps Telegram files safe; only local cache is cleared.',
            value: settings.clearCacheOnSignOut,
            onChanged: ref.read(appSettingsControllerProvider).setClearCacheOnSignOut,
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
      final ok = await ref.read(uploadNotificationServiceProvider).requestPermission();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _PremiumSwitchTile(
            icon: Icons.cloud_done_outlined,
            iconColor: Colors.purple,
            title: 'Upload completed alerts',
            subtitle: 'Show a local alert when uploads finish.',
            value: settings.uploadCompletedAlerts,
            onChanged: (value) => _setNotificationToggle(context, ref, complete: value),
          ),
          _PremiumSwitchTile(
            icon: Icons.cloud_off_outlined,
            iconColor: Colors.purple,
            title: 'Upload failed alerts',
            subtitle: 'Show a local alert when uploads fail.',
            value: settings.uploadFailedAlerts,
            onChanged: (value) => _setNotificationToggle(context, ref, failed: value),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Reusable Premium Design UI Components
// ==========================================

class _CategoryNavCard extends StatelessWidget {
  const _CategoryNavCard({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.lgR,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.lgR,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Left Icon with soft tinted circle background
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: AppRadii.smR,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Title & Subtitle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Optional Status Text/Badge
                if (statusText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                // Chevron icon
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSwitchTile extends StatelessWidget {
  const _PremiumSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: value ? scheme.primary.withValues(alpha: 0.04) : scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: value ? scheme.primary.withValues(alpha: 0.35) : scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          if (value)
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.lgR,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: AppRadii.lgR,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: value ? scheme.primary.withValues(alpha: 0.12) : iconColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: value ? scheme.primary : iconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Title / Subtitle
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
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Switch
                Switch(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumActionTile extends StatelessWidget {
  const _PremiumActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.lgR,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.lgR,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Trailing Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 24,
                ),
              ],
            ),
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
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.onTap,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm + 4,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? scheme.onSurface).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: iconWidget ?? Icon(icon, size: 18, color: iconColor ?? scheme.onSurface),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadii.mdR,
              child: content,
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
