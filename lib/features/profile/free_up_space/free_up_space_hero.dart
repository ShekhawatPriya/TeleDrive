part of '../free_up_space_screen.dart';

class _FreeUpHeroCard extends StatelessWidget {
  const _FreeUpHeroCard({required this.state});

  final FreeUpSpaceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasItems = state.eligibleCount > 0;
    final isScanning = state.scanning;

    final (sizeMain, sizeUnit) = _splitSize(state.eligibleBytes);

    final supportText = isScanning
        ? 'Scanning your gallery for backed-up itemsâ€¦'
        : hasItems
        ? 'from ${state.eligibleCount} items on this device'
        : 'Nothing on this device is ready to remove.';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadii.xlR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'RECLAIMABLE ON THIS DEVICE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isScanning)
            _ScanningSizePlaceholder()
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sizeMain,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    sizeUnit,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            supportText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (hasItems && !isScanning) ...[
            const SizedBox(height: AppSpacing.lg),
            _MediaProportionBar(
              photoBytes: state.photoBytes,
              videoBytes: state.videoBytes,
              photoCount: state.photoCount,
              videoCount: state.videoCount,
            ),
          ],
        ],
      ),
    );
  }

  static (String, String) _splitSize(int bytes) {
    final formatted = bytes > 0 ? formatFileSize(bytes) : '0 MB';
    final parts = formatted.split(' ');
    if (parts.length == 2) return (parts[0], parts[1]);
    return (formatted, '');
  }
}

class _ScanningSizePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Calculatingâ€¦',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _MediaProportionBar extends StatelessWidget {
  const _MediaProportionBar({
    required this.photoBytes,
    required this.videoBytes,
    required this.photoCount,
    required this.videoCount,
  });

  final int photoBytes;
  final int videoBytes;
  final int photoCount;
  final int videoCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = photoBytes + videoBytes;
    final photoFraction = total > 0 ? photoBytes / total : 0.5;
    final videoFraction = total > 0 ? videoBytes / total : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (photoFraction > 0)
                  Expanded(
                    flex: (photoFraction * 1000).round().clamp(1, 1000),
                    child: Container(color: scheme.primary),
                  ),
                if (photoFraction > 0 && videoFraction > 0)
                  const SizedBox(width: 2),
                if (videoFraction > 0)
                  Expanded(
                    flex: (videoFraction * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: scheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _LegendDot(color: scheme.primary, label: '$photoCount photos'),
            const SizedBox(width: AppSpacing.md),
            _LegendDot(
              color: scheme.primary.withValues(alpha: 0.45),
              label: '$videoCount videos',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
