part of '../settings_screen.dart';

class _BackupDiagnosticsCard extends StatelessWidget {
  const _BackupDiagnosticsCard({
    required this.diagnostics,
    required this.running,
    this.margin = EdgeInsets.zero,
  });

  final GalleryBackupDiagnostics diagnostics;
  final bool running;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final rows = <({String label, String value, bool isError})>[
      (
        label: 'Started',
        value: _time(diagnostics.lastScanStartedAt),
        isError: false,
      ),
      (
        label: 'Completed',
        value: _time(diagnostics.lastScanCompletedAt),
        isError: false,
      ),
      (
        label: 'Duration',
        value: diagnostics.scanDuration == null
            ? '-'
            : '${diagnostics.scanDuration!.inMilliseconds} ms',
        isError: false,
      ),
      (
        label: 'Scan mode',
        value: diagnostics.indexingStrategy.label,
        isError: false,
      ),
      (
        label: 'MediaStore / path',
        value:
            '${diagnostics.mediaStoreItemsScanned} / ${diagnostics.pathItemsScanned}',
        isError: false,
      ),
      (
        label: 'Merged candidates',
        value: '${diagnostics.mergedCandidates}',
        isError: false,
      ),
      (
        label: 'Skipped uploaded',
        value: '${diagnostics.skippedAlreadyUploaded}',
        isError: false,
      ),
      (
        label: 'Skipped queued',
        value: '${diagnostics.skippedAlreadyQueued}',
        isError: false,
      ),
      (
        label: 'Skipped permission',
        value: '${diagnostics.skippedPermission}',
        isError: false,
      ),
      (
        label: 'Skipped invalid',
        value: '${diagnostics.skippedInvalid}',
        isError: false,
      ),
      (label: 'Enqueued', value: '${diagnostics.enqueued}', isError: false),
      (
        label: 'Scan / queue limit',
        value: '${diagnostics.scanLimit} / ${diagnostics.queueLimit}',
        isError: false,
      ),
      (
        label: 'Last uploaded marker',
        value: _time(diagnostics.lastUploadCompleteMarker),
        isError: false,
      ),
      if (diagnostics.lastError != null)
        (
          label: 'Last scan error',
          value: diagnostics.lastError!,
          isError: true,
        ),
      if (diagnostics.lastEnqueueError != null)
        (
          label: 'Last enqueue error',
          value: diagnostics.lastEnqueueError!,
          isError: true,
        ),
    ];

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.5),
        ),
        boxShadow: isDark
            ? null
            : AppElevation.shadowFor(AppElevation.level1, Brightness.light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SettingsIconBadge(
                icon: Icons.monitor_heart_outlined,
                color: scheme.primary,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Scan report',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AnimatedSwitcher(
                duration: AppDurations.short4,
                switchInCurve: AppEasing.standard,
                switchOutCurve: AppEasing.standard,
                child: _SettingsStatusPill(
                  key: ValueKey(running),
                  label: running ? 'Scanning' : 'Idle',
                  color: running ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(
              alpha: isDark ? 0.16 : 0.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      row.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: theme.textTheme
                          .code(row.isError ? scheme.error : scheme.onSurface)
                          .copyWith(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          for (final note in diagnostics.notes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _time(DateTime? value) {
    if (value == null) return '-';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
