part of '../settings_screen.dart';

class _FlatTileText extends StatelessWidget {
  const _FlatTileText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
            height: 1.2,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _FlatSwitchTile extends StatelessWidget {
  const _FlatSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: _FlatTileText(title: title, subtitle: subtitle),
              ),
              const SizedBox(width: AppSpacing.md),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlatNumberTile extends StatelessWidget {
  const _FlatNumberTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDec = value > min;
    final canInc = value < max;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _FlatTileText(title: title, subtitle: subtitle),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton.filledTonal(
            tooltip: 'Decrease',
            onPressed: canDec
                ? () => onChanged((value - step).clamp(min, max).toInt())
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Increase',
            onPressed: canInc
                ? () => onChanged((value + step).clamp(min, max).toInt())
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _WarningText extends StatelessWidget {
  const _WarningText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatStrategyTile extends StatelessWidget {
  const _FlatStrategyTile({required this.value, required this.onChanged});

  final GalleryBackupIndexingStrategy value;
  final ValueChanged<GalleryBackupIndexingStrategy> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _FlatTileText(
              title: 'Indexing strategy',
              subtitle: value == GalleryBackupIndexingStrategy.mediaStoreOnly
                  ? 'Uses Android MediaStore indexing only.'
                  : 'Path scanning is limited to accessible public media directories.',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          DropdownButton<GalleryBackupIndexingStrategy>(
            value: value,
            underline: const SizedBox.shrink(),
            items: GalleryBackupIndexingStrategy.values
                .map(
                  (strategy) => DropdownMenuItem(
                    value: strategy,
                    child: Text(strategy.label),
                  ),
                )
                .toList(),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _FlatActionTile extends StatelessWidget {
  const _FlatActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: _FlatTileText(title: title, subtitle: subtitle),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
