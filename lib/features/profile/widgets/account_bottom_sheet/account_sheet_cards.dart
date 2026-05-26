part of '../account_bottom_sheet.dart';

extension _AccountSheetCards on _AccountBottomSheetState {
  Widget _buildStorageCard(BuildContext context, StorageSummary summary) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final used = summary.totalBytes;
    // Audio rolls into Others to keep the existing 4-category palette.
    final categories = [
      _StorageCategory('Photos', summary.imageBytes, const Color(0xFFFF453A)),
      _StorageCategory('Videos', summary.videoBytes, const Color(0xFFFF9F0A)),
      _StorageCategory(
        'Documents',
        summary.documentBytes,
        const Color(0xFF0A84FF),
      ),
      _StorageCategory(
        'Others',
        summary.audioBytes + summary.otherBytes,
        const Color(0xFF8E8E93),
      ),
    ];

    final activeCategories = categories.where((c) => c.size > 0).toList();
    final totalCategorizedSize = activeCategories.fold<int>(
      0,
      (sum, c) => sum + c.size,
    );

    return _ProfileSheetSection(
      child: InkWell(
        onTap: () => context.safePush('/profile?scrollToStorage=true'),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Telegram Drive',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${formatFileSize(used)} of Unlimited used',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: 10,
                  color: scheme.brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.grey[300],
                  child: used == 0 || activeCategories.isEmpty
                      ? const SizedBox.expand()
                      : Row(
                          children: activeCategories.map((cat) {
                            return Expanded(
                              flex: (cat.size / totalCategorizedSize * 10000)
                                  .clamp(1, 10000)
                                  .toInt(),
                              child: Container(color: cat.color),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 12.0,
                runSpacing: 4.0,
                alignment: WrapAlignment.start,
                children: categories.map((cat) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.safePush('/profile?scrollToStorage=true'),
                  style: TextButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Manage storage',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupCard(BuildContext context, bool backupOn) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _ProfileSheetSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (backupOn ? scheme.primary : scheme.outlineVariant)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                backupOn ? Icons.cloud_queue_rounded : Icons.cloud_off_rounded,
                color: backupOn ? scheme.primary : scheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backupOn ? 'Backup is on' : 'Backup is off',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    backupOn
                        ? 'New photos and videos are scanned and transferred locally through TDLib.'
                        : 'Turn on photo and video backup. Settings controls limits and indexing only.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final next = !backupOn;
                        await ref
                            .read(appSettingsControllerProvider)
                            .setGalleryBackupEnabled(next);
                        if (next) {
                          await ref
                              .read(galleryBackupControllerProvider)
                              .scanNow(reason: 'profile_toggle');
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              backupOn
                                  ? 'Backup turned off. Queued backup items are paused; uploaded history is kept.'
                                  : 'Backup enabled. Scanning now.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        backupOn ? 'Turn off backup' : 'Turn on backup',
                      ),
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

class _StorageCategory {
  final String name;
  final int size;
  final Color color;

  const _StorageCategory(this.name, this.size, this.color);
}
