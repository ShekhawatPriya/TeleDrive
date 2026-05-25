import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../cache_controller.dart';
import 'cache_item_row.dart';

class LocalCacheCard extends ConsumerWidget {
  const LocalCacheCard({this.embed = false, super.key});

  final bool embed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheController = ref.watch(cacheControllerProvider);
    final state = cacheController.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Cache status pill styling
    Color statusBgColor;
    Color statusTextColor;
    if (state.status == 'Clean') {
      statusBgColor = isDark
          ? Colors.green.withValues(alpha: 0.18)
          : Colors.green.withValues(alpha: 0.08);
      statusTextColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
    } else if (state.status == 'Moderate') {
      statusBgColor = scheme.secondaryContainer.withValues(alpha: 0.7);
      statusTextColor = scheme.onSecondaryContainer;
    } else {
      statusBgColor = isDark
          ? Colors.orange.withValues(alpha: 0.2)
          : Colors.orange.withValues(alpha: 0.1);
      statusTextColor = isDark
          ? Colors.orange.shade300
          : Colors.orange.shade800;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            Expanded(
              child: Text(
                'Device Cache',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: AppRadii.smR,
              ),
              child: Text(
                state.status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Hero section: overall cached size
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatFileSize(state.totalSize),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'used locally',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Additional details
        Text(
          '${state.estimatedItems} items cached on your phone${state.lastScanTime != null ? ' · Scanned at ${_formatTime(state.lastScanTime!)}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(),

        // Itemized breakdown rows
        CacheItemRow(
          icon: Icons.photo_outlined,
          iconColor: scheme.primary,
          label: 'Thumbnails & Avatars',
          description: 'Small media previews and profile pictures.',
          bytes: state.thumbnailSize,
        ),
        CacheItemRow(
          icon: Icons.play_circle_outline_rounded,
          iconColor: scheme.tertiary,
          label: 'Previews & Media',
          description: 'Large in-app preview files and media buffers.',
          bytes: state.previewSize,
        ),
        CacheItemRow(
          icon: Icons.insert_drive_file_outlined,
          iconColor: scheme.secondary,
          label: 'Documents & Originals',
          description: 'Files downloaded to open in external apps.',
          bytes: state.originalSize,
        ),
        CacheItemRow(
          icon: Icons.backup_outlined,
          iconColor: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          label: 'Upload & Temp Staging',
          description: 'Temporary picker files and upload fragments.',
          bytes: state.uploadStagingSize,
        ),

        const SizedBox(height: AppSpacing.sm),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),

        // Reassurance and trust building info boxes
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: AppRadii.mdR,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '100% Safe to Clear',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Clearing local cache only removes temporary device files. It will not delete your remote uploaded files, folders, shares, or remote cloud library on Telegram.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.speed_outlined, size: 16, color: scheme.secondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Cache Benefits',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Cache files make images load instantly, enhance preview performance, and let you open recently accessed documents offline without re-downloading.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Clear Cache Action Button
        Row(
          children: [
            Expanded(
              child: state.isClearing
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Clearing device cache...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: state.totalSize == 0
                          ? null
                          : () async {
                              final controller = ref.read(
                                cacheControllerProvider,
                              );
                              await controller.clearCache();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Device cache cleared successfully!',
                                    ),
                                    backgroundColor: scheme.inverseSurface,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear cache'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: state.totalSize == 0
                              ? scheme.outlineVariant
                              : scheme.outline,
                        ),
                      ),
                    ),
            ),
            if (!state.isClearing) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                onPressed: state.isLoading
                    ? null
                    : () =>
                          ref.read(cacheControllerProvider).refreshCacheStats(),
                icon: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Scan / Refresh Cache',
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => context.push('/profile/free-up-space'),
            icon: const Icon(Icons.cloud_done_outlined, size: 18),
            label: const Text('Free up backed-up media'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Remove local copies of Auto Backup photos and videos already safe in TeleDrive.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
      ],
    );

    if (embed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: content,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: content,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
