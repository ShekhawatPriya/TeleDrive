import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/auth_user.dart';
import '../../models/drive_models.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import 'theme_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final user = auth.user;
    final files = drive.files;
    final used = drive.state.usedStorage;
    final scheme = Theme.of(context).colorScheme;
    final storageCategories = _storageCategories(files, scheme);

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/drive');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/drive');
              }
            },
          ),
          title: const Text('Account'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, 112),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: AppSpacing.md),
            _TelegramStatusCard(
              connected: auth.telegramConnected,
              telegramId: user?.telegramId,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('Storage'),
            _StorageCard(used: used, categories: storageCategories),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('Profile'),
            _InfoCard(
              children: [
                _ActionRow(
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: user?.username == null
                      ? 'Not set'
                      : '@${user!.username}',
                ),
                _ActionRow(
                  icon: Icons.badge_outlined,
                  label: 'Telegram ID',
                  value: user?.telegramId == null ? '-' : '${user!.telegramId}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('Appearance'),
            _ThemeSelector(
              mode: ref.watch(themeControllerProvider).mode,
              onChanged: ref.read(themeControllerProvider).setMode,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('About'),
            _InfoCard(
              children: [
                _ActionRow(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: '1.0.0',
                ),
                _ActionRow(
                  icon: Icons.code,
                  label: 'Open Source',
                  value: 'GitHub',
                  onTap: () => AppConfig.openRepository(),
                ),
                _ActionRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => context.push('/privacy'),
                ),
                _ActionRow(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => context.push('/terms'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoCard(
              children: [
                _ActionRow(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  destructive: true,
                  onTap: () => ref.read(authControllerProvider).logout(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'TeleDrive — A DevsDoCode Project',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : 'TeleDrive user';
    final subtitle = user?.username != null
        ? '@${user!.username}'
        : 'ID ${user?.telegramId ?? '-'}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            ProfileAvatar(user: user, size: 64),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
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

class _TelegramStatusCard extends StatelessWidget {
  const _TelegramStatusCard({
    required this.connected,
    required this.telegramId,
  });

  final bool? connected;
  final int? telegramId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isConnected = connected == true;
    final container = isConnected
        ? scheme.tertiaryContainer
        : scheme.errorContainer;
    final onContainer = isConnected
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: container,
        borderRadius: AppRadii.mdR,
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle_rounded : Icons.error_outline,
            color: onContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected
                      ? 'Telegram connected'
                      : 'Telegram not connected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Storage is active${telegramId == null ? '' : ' for ID $telegramId'}.'
                      : 'Connect Telegram to upload and access files.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onContainer.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.used, required this.categories});

  final int used;
  final List<_StorageCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nonEmpty = categories.where((c) => c.bytes > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Storage used', style: theme.textTheme.titleMedium),
                ),
                Text(
                  formatFileSize(used),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: nonEmpty.isEmpty
                    ? ColoredBox(color: scheme.surfaceContainerHighest)
                    : Row(
                        children: [
                          for (final c in nonEmpty)
                            Expanded(
                              flex: ((c.bytes / used) * 1000)
                                  .round()
                                  .clamp(1, 1000),
                              child: Container(color: c.color),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              used == 0 ? 'No storage used yet' : '${formatFileSize(used)} stored in Telegram',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final c in categories)
              _StorageCategoryRow(category: c, total: used),
          ],
        ),
      ),
    );
  }
}

class _StorageCategoryRow extends StatelessWidget {
  const _StorageCategoryRow({required this.category, required this.total});

  final _StorageCategory category;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0.0 : category.bytes / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(category.label, style: theme.textTheme.bodyMedium)),
          Text(
            '${formatFileSize(category.bytes)} (${(pct * 100).toStringAsFixed(pct == 0 ? 0 : 1)}%)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageCategory {
  const _StorageCategory({
    required this.label,
    required this.bytes,
    required this.color,
  });
  final String label;
  final int bytes;
  final Color color;
}

List<_StorageCategory> _storageCategories(
  List<DriveFile> files,
  ColorScheme scheme,
) {
  var photos = 0, videos = 0, documents = 0, other = 0;
  for (final file in files) {
    if (file.kind == FileKind.image) {
      photos += file.size;
    } else if (file.kind == FileKind.video) {
      videos += file.size;
    } else if ({
      FileKind.pdf, FileKind.doc, FileKind.sheet,
      FileKind.slides, FileKind.code, FileKind.text,
    }.contains(file.kind)) {
      documents += file.size;
    } else {
      other += file.size;
    }
  }
  return [
    _StorageCategory(label: 'Photos', bytes: photos, color: scheme.primary),
    _StorageCategory(label: 'Videos', bytes: videos, color: scheme.tertiary),
    _StorageCategory(label: 'Documents', bytes: documents, color: scheme.secondary),
    _StorageCategory(
      label: 'Other',
      bytes: other,
      color: scheme.onSurfaceVariant.withValues(alpha: .55),
    ),
  ];
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Light'),
            icon: Icon(Icons.light_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Dark'),
            icon: Icon(Icons.dark_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('Auto'),
            icon: Icon(Icons.phone_android),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = destructive ? scheme.error : scheme.onSurfaceVariant;

    return ListTile(
      leading: Icon(icon, color: tint),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: destructive ? scheme.error : scheme.onSurface,
        ),
      ),
      trailing: value != null
          ? Text(
              value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : (onTap == null
              ? null
              : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, 0, 0, AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
