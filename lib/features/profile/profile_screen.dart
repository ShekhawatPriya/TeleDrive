import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/auth_user.dart';
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
    final folders = drive.folders;
    final used = drive.state.usedStorage;
    final total = drive.state.totalStorage;
    final storageRatio = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);

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
          _StorageCard(
            used: used,
            total: total,
            ratio: storageRatio,
            fileCount: files.length,
            folderCount: folders.length,
            mediaCount: drive.mediaFiles.length,
            starredCount: files.where((f) => f.starred).length,
          ),
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
              _InfoRow(
                icon: Icons.person_outline,
                label: 'User ID',
                value: user?.userId == null ? '-' : '${user!.userId}',
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
            _ProfilePhoto(user: user),
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

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial =
        (user?.firstName.isNotEmpty == true ? user!.firstName[0] : '?')
            .toUpperCase();
    final photoUrl = user?.photoUrl?.trim();

    Widget fallback() => Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) return fallback();

    Widget image;
    if (photoUrl.startsWith('data:image')) {
      final comma = photoUrl.indexOf(',');
      final payload = comma == -1 ? '' : photoUrl.substring(comma + 1);
      try {
        image = Image.memory(
          base64Decode(payload),
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        return fallback();
      }
    } else {
      image = CachedNetworkImage(
        imageUrl: photoUrl,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback(),
        errorWidget: (_, __, ___) => fallback(),
      );
    }

    return ClipOval(child: image);
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
  const _StorageCard({
    required this.used,
    required this.total,
    required this.ratio,
    required this.fileCount,
    required this.folderCount,
    required this.mediaCount,
    required this.starredCount,
  });

  final int used;
  final int total;
  final double ratio;
  final int fileCount;
  final int folderCount;
  final int mediaCount;
  final int starredCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  '${(ratio * 100).toStringAsFixed(ratio < .01 && ratio > 0 ? 2 : 1)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatFileSize(used)} of ${formatFileSize(total)} used',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StoragePill(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Files',
                  value: '$fileCount',
                ),
                _StoragePill(
                  icon: Icons.folder_outlined,
                  label: 'Folders',
                  value: '$folderCount',
                ),
                _StoragePill(
                  icon: Icons.photo_library_outlined,
                  label: 'Media',
                  value: '$mediaCount',
                ),
                _StoragePill(
                  icon: Icons.star_border,
                  label: 'Starred',
                  value: '$starredCount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoragePill extends StatelessWidget {
  const _StoragePill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Text(
            '$value $label',
            style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
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
