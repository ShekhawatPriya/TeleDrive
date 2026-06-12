part of '../free_up_space_screen.dart';

class _FreeUpMessageCard extends StatelessWidget {
  const _FreeUpMessageCard({
    required this.icon,
    required this.title,
    required this.body,
    this.subtext,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? subtext;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.32),
        borderRadius: AppRadii.lgR,
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: AppRadii.smR,
            ),
            child: Icon(icon, color: scheme.onSecondaryContainer, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtext!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _FreeUpLimitedAccessCard extends StatelessWidget {
  const _FreeUpLimitedAccessCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.40),
        borderRadius: AppRadii.mdR,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: scheme.onTertiaryContainer,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Only selected photos are visible to TeleDrive. Allow full photo access to find everything that can be freed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeUpBottomBar extends StatelessWidget {
  const _FreeUpBottomBar({
    required this.state,
    required this.onScan,
    required this.onFree,
  });

  final FreeUpSpaceState state;
  final VoidCallback onScan;
  final VoidCallback onFree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final label = state.scanning
        ? 'Scanning device…'
        : state.deleting
        ? 'Waiting for confirmation…'
        : state.permissionDenied
        ? 'Allow photo access'
        : state.eligibleBytes <= 0
        ? 'Nothing to free up'
        : 'Free up ${formatFileSize(state.eligibleBytes)}';

    final helperText = state.scanning
        ? 'Checking which items are safe to remove…'
        : state.deleting
        ? 'Confirm in the system dialog to continue.'
        : state.permissionDenied
        ? 'TeleDrive needs photo access to find backed-up items.'
        : state.eligibleBytes <= 0
        ? 'Run a scan when more items have been backed up.'
        : 'Cloud copies remain in TeleDrive.';

    final onPressed = state.scanning || state.deleting
        ? null
        : state.permissionDenied
        ? onScan
        : state.eligibleBytes <= 0
        ? null
        : onFree;

    final isBusy = state.scanning || state.deleting;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                child: isBusy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(label),
                        ],
                      )
                    : Text(label),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                helperText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
