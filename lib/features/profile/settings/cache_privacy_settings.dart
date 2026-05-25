part of '../settings_screen.dart';

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
              'TeleDrive keeps thumbnails and previews on this device so files open instantly. Clearing them only frees space - your files in Telegram are untouched.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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
              'Keep cache clearing separate from removing Auto Backup gallery copies.',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _FlatActionTile(
            title: 'Free up backed-up media',
            subtitle:
                'Remove local copies of Auto Backup photos and videos already safe in TeleDrive.',
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
