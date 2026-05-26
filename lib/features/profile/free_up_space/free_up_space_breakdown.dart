part of '../free_up_space_screen.dart';

class _FreeUpSafetyCard extends StatelessWidget {
  const _FreeUpSafetyCard();

  @override
  Widget build(BuildContext context) {
    return const _FreeUpSectionCard(
      title: 'Safety checks',
      subtitle: 'What we always verify before deleting',
      children: [
        _FreeUpIconRow(
          icon: Icons.cloud_done_outlined,
          text: 'Only Auto Backup items',
        ),
        _FreeUpIconRow(
          icon: Icons.verified_outlined,
          text: 'Cloud copy verified before deleting',
        ),
        _FreeUpIconRow(
          icon: Icons.block_outlined,
          text: 'Manual uploads are ignored',
        ),
        _FreeUpIconRow(
          icon: Icons.phone_android_rounded,
          text: 'Android asks before removing media',
          isLast: true,
        ),
      ],
    );
  }
}

class _FreeUpBreakdownCard extends StatelessWidget {
  const _FreeUpBreakdownCard({required this.state});

  final FreeUpSpaceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _FreeUpSectionCard(
      title: 'Breakdown',
      subtitle: _relativeTime(state.lastScanAt),
      children: [
        _MediaBreakdownRow(
          icon: Icons.photo_outlined,
          label: 'Photos',
          count: state.photoCount,
          size: formatFileSize(state.photoBytes),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MediaBreakdownRow(
          icon: Icons.movie_outlined,
          label: 'Videos',
          count: state.videoCount,
          size: formatFileSize(state.videoBytes),
          isLast: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
        Theme(
          data: theme.copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: AppSpacing.xs),
            iconColor: scheme.onSurfaceVariant,
            collapsedIconColor: scheme.onSurfaceVariant,
            title: Text(
              'Why some items are skipped',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              _FreeUpMetricRow(
                label: 'Not backed up yet',
                value: '${state.skippedNotBackedUp}',
              ),
              _FreeUpMetricRow(
                label: 'Manual uploads ignored',
                value: '${state.skippedManualUpload}',
              ),
              _FreeUpMetricRow(
                label: 'Cloud copy unavailable',
                value: '${state.skippedRemoteMissing}',
              ),
              _FreeUpMetricRow(
                label: 'Already cleaned',
                value: '${state.skippedAlreadyCleaned}',
              ),
              _FreeUpMetricRow(
                label: 'Currently uploading',
                value: '${state.skippedCurrentlyUploading}',
              ),
              _FreeUpMetricRow(
                label: 'Unsupported local URI',
                value: '${state.skippedUnsupportedUri + state.skippedPathOnly}',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime? value) {
    if (value == null) return 'Not checked yet';
    final elapsed = DateTime.now().difference(value);
    if (elapsed.inMinutes < 1) return 'Updated just now';
    if (elapsed.inHours < 1) return 'Updated ${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return 'Updated ${elapsed.inHours} hr ago';
    return 'Updated ${elapsed.inDays} days ago';
  }
}

class _MediaBreakdownRow extends StatelessWidget {
  const _MediaBreakdownRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.size,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final String size;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: AppRadii.smR,
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          size,
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
