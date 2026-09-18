part of '../settings_screen.dart';

/// Connected Material rows on Android and inset grouped rows on iOS. A row that owns a
/// footnote should be passed as a single `Column` child so no divider
/// splits the pair.
class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({
    required this.children,
    this.dividerIndent = AppSpacing.md,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CupertinoListSection.insetGrouped(
          margin: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          additionalDividerMargin: 0,
          dividerMargin: dividerIndent,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          children: children,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Material(
                color: scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 24 : 4),
                    bottom: Radius.circular(i == children.length - 1 ? 24 : 4),
                  ),
                  side: MediaQuery.highContrastOf(context)
                      ? BorderSide(color: scheme.outline)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: children[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tinted rounded-square badge that anchors a settings row's icon.
class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({
    required this.icon,
    required this.color,
    this.size = 36,
    this.child,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Optional replacement for the icon (e.g. a progress spinner).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).platform == TargetPlatform.iOS
            ? color
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child:
            child ??
            Icon(
              icon,
              color: Theme.of(context).platform == TargetPlatform.iOS
                  ? Colors.white
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              size: size * 0.55,
            ),
      ),
    );
  }
}

/// Compact stadium pill with a colored dot and label, used for live status.
class _SettingsStatusPill extends StatelessWidget {
  const _SettingsStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final statusScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: theme.brightness,
      contrastLevel: MediaQuery.highContrastOf(context) ? 1 : 0,
    );
    final ink = theme.platform == TargetPlatform.iOS
        ? color
        : statusScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        color: theme.platform == TargetPlatform.iOS
            ? color.withValues(alpha: isDark ? 0.16 : 0.12)
            : statusScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation row inside a [_SettingsGroupCard]: icon badge, title/subtitle,
/// optional trailing widget (status pill or text), and a chevron.
class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: theme.platform == TargetPlatform.iOS ? AppSpacing.sm : 16,
        ),
        child: Row(
          children: [
            if (theme.platform == TargetPlatform.iOS ||
                MediaQuery.textScalerOf(context).scale(14) <= 20) ...[
              _SettingsIconBadge(icon: icon, color: iconColor),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,

                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(height: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
