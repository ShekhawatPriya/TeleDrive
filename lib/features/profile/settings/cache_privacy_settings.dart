part of '../settings_screen.dart';

class CacheStorageSettingsScreen extends ConsumerWidget {
  const CacheStorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(cacheControllerProvider).state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadii.lgR,
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.18 : 0.5,
                ),
              ),
              boxShadow: isDark
                  ? null
                  : AppElevation.shadowFor(
                      AppElevation.level1,
                      Brightness.light,
                    ),
            ),
            child: Column(
              children: [
                const _SettingsIconBadge(
                  icon: Icons.cleaning_services_rounded,
                  color: _accentCache,
                  size: 56,
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Local Cache Size',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Thumbnails and previews are kept on this device so files open instantly. Clearing them only frees space — files in Telegram stay untouched.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Maintenance'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsActionTile(
                    title: 'Free up backed-up media',
                    subtitle:
                        'Remove local copies of Auto Backup photos and videos already safe in TeleDrive.',
                    icon: Icons.auto_delete_outlined,
                    iconColor: _accentCache,
                    onTap: () => context.push('/profile/free-up-space'),
                  ),
                ],
              ),
            ],
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
        centerTitle: true,
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
          _SettingsPageHeader(
            icon: Icons.shield_outlined,
            color: _accentPrivacy,
            title: 'Privacy controls',
            description:
                'Decide how deletions, public share links, and sign-out cleanup behave on this device.',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Deletion'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsSwitchTile(
                    title: 'Trash / safer delete',
                    subtitle: settings.trashEnabled
                        ? 'Deletes move to Trash first.'
                        : 'Deletes are permanent immediately.',
                    icon: Icons.restore_from_trash_rounded,
                    iconColor: _accentPrivacy,
                    value: settings.trashEnabled,
                    onChanged: ref
                        .read(appSettingsControllerProvider)
                        .setTrashEnabled,
                  ),
                  _SettingsActionTile(
                    title: 'Trash bin',
                    subtitle: 'Restore items or delete them forever.',
                    icon: Icons.delete_outline_rounded,
                    iconColor: _accentPrivacy,
                    onTap: () => context.push('/settings/trash'),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Sharing'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsSwitchTile(
                    title: 'Confirm public share links',
                    subtitle: 'Ask before creating links anyone can open.',
                    icon: Icons.public_rounded,
                    iconColor: _accentPrivacy,
                    value: settings.confirmPublicShares,
                    onChanged: ref
                        .read(appSettingsControllerProvider)
                        .setConfirmPublicShares,
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Sign Out'),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  _SettingsSwitchTile(
                    title: 'Clear local cache on sign out',
                    subtitle:
                        'Keeps Telegram files safe; only local cache is cleared.',
                    icon: Icons.logout_rounded,
                    iconColor: _accentPrivacy,
                    value: settings.clearCacheOnSignOut,
                    onChanged: ref
                        .read(appSettingsControllerProvider)
                        .setClearCacheOnSignOut,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
