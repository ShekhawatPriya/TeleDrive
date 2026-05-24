part of '../settings_screen.dart';

class _BackupDiagnosticsCard extends StatelessWidget {
  const _BackupDiagnosticsCard({
    required this.diagnostics,
    required this.running,
  });

  final GalleryBackupDiagnostics diagnostics;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <({String label, String value})>[
      (label: 'State', value: running ? 'Scanning' : 'Idle'),
      (label: 'Started', value: _time(diagnostics.lastScanStartedAt)),
      (label: 'Completed', value: _time(diagnostics.lastScanCompletedAt)),
      (
        label: 'Duration',
        value: diagnostics.scanDuration == null
            ? '-'
            : '${diagnostics.scanDuration!.inMilliseconds} ms',
      ),
      (label: 'Strategy', value: diagnostics.indexingStrategy.label),
      (
        label: 'MediaStore / path',
        value:
            '${diagnostics.mediaStoreItemsScanned} / ${diagnostics.pathItemsScanned}',
      ),
      (label: 'Merged candidates', value: '${diagnostics.mergedCandidates}'),
      (
        label: 'Skipped uploaded',
        value: '${diagnostics.skippedAlreadyUploaded}',
      ),
      (label: 'Skipped queued', value: '${diagnostics.skippedAlreadyQueued}'),
      (label: 'Skipped permission', value: '${diagnostics.skippedPermission}'),
      (label: 'Skipped invalid', value: '${diagnostics.skippedInvalid}'),
      (label: 'Enqueued', value: '${diagnostics.enqueued}'),
      (
        label: 'Scan / queue limit',
        value: '${diagnostics.scanLimit} / ${diagnostics.queueLimit}',
      ),
      (
        label: 'Last uploaded marker',
        value: _time(diagnostics.lastUploadCompleteMarker),
      ),
      if (diagnostics.lastError != null)
        (label: 'Last scan error', value: diagnostics.lastError!),
      if (diagnostics.lastEnqueueError != null)
        (label: 'Last enqueue error', value: diagnostics.lastEnqueueError!),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.mdR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
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
