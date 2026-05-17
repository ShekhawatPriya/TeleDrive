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
    final storageCategories = _storageCategories(
      files,
      Theme.of(context).colorScheme,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 12),
          _TelegramStatusCard(
            connected: auth.telegramConnected,
            telegramId: user?.telegramId,
          ),
          const SizedBox(height: 24),
          _SectionLabel('STORAGE'),
          _StorageCard(used: used, categories: storageCategories),
          const SizedBox(height: 24),
          _SectionLabel('PROFILE'),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.alternate_email,
                label: 'Username',
                value: user?.username == null
                    ? 'Not set'
                    : '@${user!.username}',
              ),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Telegram ID',
                value: user?.telegramId == null ? '-' : '${user!.telegramId}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('APPEARANCE'),
          _ThemeSelector(
            mode: ref.watch(themeControllerProvider).mode,
            onChanged: ref.read(themeControllerProvider).setMode,
          ),
          const SizedBox(height: 24),
          _SectionLabel('ABOUT'),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          Text(
            'TeleDrive - A DevsDoCode Project',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    final displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : 'TeleDrive user';
    final subtitle = user?.username != null
        ? '@${user!.username}'
        : 'ID ${user?.telegramId ?? '-'}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatar(user: user),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.send_outlined,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
    final isConnected = connected == true;
    final statusColor = isConnected
        ? AppColors.success
        : theme.colorScheme.error;
    final bg = statusColor.withValues(alpha: .12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Telegram connected' : 'Telegram not connected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isConnected
                      ? 'Storage is active${telegramId == null ? '' : ' for ID $telegramId'}.'
                      : 'Connect Telegram to upload and access files.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Icon(
            isConnected ? Icons.check_circle : Icons.error_outline,
            color: statusColor,
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
    final nonEmpty = categories
        .where((category) => category.bytes > 0)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Storage used',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatFileSize(used),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 12,
                child: used == 0
                    ? ColoredBox(color: theme.colorScheme.secondary)
                    : Row(
                        children: [
                          for (final category in nonEmpty)
                            Expanded(
                              flex: ((category.bytes / used) * 1000)
                                  .round()
                                  .clamp(1, 1000)
                                  .toInt(),
                              child: ColoredBox(color: category.color),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              used == 0
                  ? 'No storage used yet'
                  : '${formatFileSize(used)} stored in Telegram',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Column(
              children: categories
                  .map(
                    (category) =>
                        _StorageCategoryRow(category: category, total: used),
                  )
                  .toList(),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(category.label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            '${formatFileSize(category.bytes)} (${(pct * 100).toStringAsFixed(pct == 0 ? 0 : 1)}%)',
            style: theme.textTheme.bodyMedium?.copyWith(
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
  ColorScheme colors,
) {
  var photos = 0;
  var videos = 0;
  var documents = 0;
  var other = 0;

  for (final file in files) {
    if (file.kind == FileKind.image) {
      photos += file.size;
    } else if (file.kind == FileKind.video) {
      videos += file.size;
    } else if ({
      FileKind.pdf,
      FileKind.doc,
      FileKind.sheet,
      FileKind.slides,
      FileKind.code,
      FileKind.text,
    }.contains(file.kind)) {
      documents += file.size;
    } else {
      other += file.size;
    }
  }

  return [
    _StorageCategory(
      label: 'Photos',
      bytes: photos,
      color: const Color(0xFFDB6B57),
    ),
    _StorageCategory(
      label: 'Videos',
      bytes: videos,
      color: const Color(0xFFEA9C3D),
    ),
    _StorageCategory(
      label: 'Documents',
      bytes: documents,
      color: const Color(0xFF6D7F5F),
    ),
    _StorageCategory(
      label: 'Other',
      bytes: other,
      color: colors.onSurfaceVariant.withValues(alpha: .55),
    ),
  ];
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (mode: ThemeMode.light, icon: Icons.light_mode_outlined, label: 'Light'),
      (mode: ThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Dark'),
      (mode: ThemeMode.system, icon: Icons.phone_android, label: 'Auto'),
    ];
    return Row(
      children: options.map((option) {
        final selected = mode == option.mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: option == options.last ? 0 : 10),
            child: _ThemeOption(
              icon: option.icon,
              label: option.label,
              selected: selected,
              onTap: () => onChanged(option.mode),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _ActionRow(icon: icon, label: label, value: value);
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
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color:
              (destructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary)
                  .withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: destructive
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
      ),
      title: Text(label, style: TextStyle(color: color)),
      trailing: value != null
          ? Text(value!, style: theme.textTheme.bodyMedium)
          : onTap == null
          ? null
          : Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}
