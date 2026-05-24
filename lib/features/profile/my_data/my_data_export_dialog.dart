part of '../my_data_screen.dart';

void _showExportDataDialog(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: Icon(
          Icons.import_export_rounded,
          size: 38,
          color: scheme.primary,
        ),
        title: const Text('Exporting Your Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TeleDrive transfers private file bytes locally through TDLib and stores Telegram references plus metadata on your configured backend.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'The backend can describe your folders, shares, refs, upload state, and backup fingerprints, but it is not a private file-byte export source.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'To download a full copy of your files, settings, and media:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _ExportDataBullet(
                text:
                    'For all Telegram account data: Use Telegram Desktop -> Settings -> Advanced -> Export Telegram data.',
              ),
              const SizedBox(height: AppSpacing.xs),
              _ExportDataBullet(
                text:
                    'For specific files in TeleDrive: Use the multi-select feature on the files tab and tap Download.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

class _ExportDataBullet extends StatelessWidget {
  const _ExportDataBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
