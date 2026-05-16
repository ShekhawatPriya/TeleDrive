import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: user?.photoUrl == null
                        ? null
                        : NetworkImage(user!.photoUrl!),
                    child: user?.photoUrl == null
                        ? Text(
                            (user?.firstName.isNotEmpty == true
                                    ? user!.firstName[0]
                                    : '?')
                                .toUpperCase(),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'TeleDrive user',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (user?.username != null) Text('@${user!.username}'),
                        Text(
                          auth.telegramConnected == true
                              ? 'Telegram connected'
                              : 'Telegram not connected',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Storage'),
                  subtitle: Text(
                    '${formatFileSize(drive.state.usedStorage)} of ${formatFileSize(drive.state.totalStorage)} used',
                  ),
                ),
                ListTile(
                  title: const Text('Theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: ref.watch(themeControllerProvider).mode,
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        ref.read(themeControllerProvider).setMode(value);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () => context.push('/privacy'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of service'),
                  onTap: () => context.push('/terms'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async => ref.read(authControllerProvider).logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
