part of '../free_up_space_screen.dart';

Future<bool?> showFreeUpSpaceConfirmationSheet(
  BuildContext context,
  FreeUpSpaceState state,
) {
  final size = formatFileSize(state.eligibleBytes);
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadii.smR,
                ),
                child: Text(
                  'CONFIRM',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Free up $size?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Removes ${state.eligibleCount} local photos and videos that Auto Backup uploaded and verified.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadii.mdR,
                ),
                child: Column(
                  children: const [
                    _FreeUpIconRow(
                      icon: Icons.cloud_done_outlined,
                      text: 'TeleDrive cloud copies stay',
                    ),
                    _FreeUpIconRow(
                      icon: Icons.block_outlined,
                      text: 'Manual uploads are not touched',
                    ),
                    _FreeUpIconRow(
                      icon: Icons.sync_disabled_rounded,
                      text: 'Items still uploading are skipped',
                    ),
                    _FreeUpIconRow(
                      icon: Icons.phone_android_rounded,
                      text: 'Android will ask you to confirm',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Continue'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
