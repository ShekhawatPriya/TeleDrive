part of '../settings_screen.dart';

class _SettingsTileText extends StatelessWidget {
  const _SettingsTileText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
            height: 1.2,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: icon != null ? AppSpacing.sm : AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              _SettingsIconBadge(
                icon: icon!,
                color: iconColor ?? scheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: _SettingsTileText(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SettingsNumberTile extends StatelessWidget {
  const _SettingsNumberTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canDec = value > min;
    final canInc = value < max;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: icon != null ? AppSpacing.sm : AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            _SettingsIconBadge(icon: icon!, color: iconColor ?? scheme.primary),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: _SettingsTileText(title: title, subtitle: subtitle),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton.filledTonal(
            tooltip: 'Decrease',
            visualDensity: VisualDensity.compact,
            onPressed: canDec
                ? () => onChanged((value - step).clamp(min, max).toInt())
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 44,
            child: AnimatedSwitcher(
              duration: AppDurations.short3,
              switchInCurve: AppEasing.standard,
              switchOutCurve: AppEasing.standard,
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Increase',
            visualDensity: VisualDensity.compact,
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

enum _SettingsNoteTone { info, warning }

/// Footnote that sits inside a [_SettingsGroupCard], glued under its row.
class _SettingsInfoNote extends StatelessWidget {
  const _SettingsInfoNote({
    required this.text,
    this.tone = _SettingsNoteTone.info,
  });

  final String text;
  final _SettingsNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = tone == _SettingsNoteTone.warning;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
          size: 16,
          color: warning
              ? AppColors.warning
              : scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: warning
          ? Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadii.smR,
              ),
              child: row,
            )
          : row,
    );
  }
}

class _SettingsStrategyTile extends StatelessWidget {
  const _SettingsStrategyTile({
    this.icon,
    this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final IconData? icon;
  final Color? iconColor;
  final GalleryBackupIndexingStrategy value;
  final ValueChanged<GalleryBackupIndexingStrategy> onChanged;

  String _subtitleFor(GalleryBackupIndexingStrategy strategy) {
    switch (strategy) {
      case GalleryBackupIndexingStrategy.mediaStoreOnly:
        return "Uses Android's photo and video library. Best for most people.";
      case GalleryBackupIndexingStrategy.filePathOnly:
        return 'Checks accessible public media folders. Use only if some items are missing.';
      case GalleryBackupIndexingStrategy.mediaStoreAndFilePath:
        return 'Combines both methods. Slower, useful for troubleshooting.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: icon != null ? AppSpacing.sm : AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            _SettingsIconBadge(icon: icon!, color: iconColor ?? scheme.primary),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: _SettingsTileText(
              title: 'Backup scan mode',
              subtitle: _subtitleFor(value),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadii.smR,
            ),
            child: DropdownButton<GalleryBackupIndexingStrategy>(
              value: value,
              isDense: true,
              underline: const SizedBox.shrink(),
              borderRadius: AppRadii.mdR,
              dropdownColor: scheme.surfaceContainerHigh,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
              ),
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
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Row(
      children: [
        if (icon != null) ...[
          _SettingsIconBadge(icon: icon!, color: iconColor ?? scheme.primary),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: _SettingsTileText(title: title, subtitle: subtitle),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          size: 20,
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: icon != null ? AppSpacing.sm : AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        child: enabled ? content : Opacity(opacity: 0.55, child: content),
      ),
    );
  }
}
