part of '../settings_screen.dart';

/// Category accent colors shared between the main settings screen and the
/// hero headers / row badges of the matching nested pages.
const _accentServer = Color(0xFF5C8FBF);
const _accentUploads = Color(0xFF6E7C97);
const _accentBackup = Color(0xFF4C8F87);
const _accentCache = Color(0xFFDCA15D);
const _accentPrivacy = Color(0xFF8BA698);
const _accentAlerts = Color(0xFFC393B5);
const _accentUpdates = Color(0xFF5C8AA8);
const _accentProject = Color(0xFF6E7C97);

Widget _settingsSectionHeader(BuildContext context, String label) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  return Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md + AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    ),
  );
}

Widget _settingsSectionIntro(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md + AppSpacing.sm,
      0,
      AppSpacing.md + AppSpacing.sm,
      AppSpacing.xs,
    ),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

/// Hero header opening a nested settings page: a card with the category's
/// accent-tinted icon badge and a short description, so each page inherits
/// the visual identity of its tile on the main settings screen.
class _SettingsPageHeader extends StatelessWidget {
  const _SettingsPageHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
      child: Row(
        children: [
          _SettingsIconBadge(icon: icon, color: color, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One-shot entrance animation for the main settings sections: each section
/// fades in and settles upward, staggered by [index].
class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.4);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.medium4,
      curve: Interval(start, 1, curve: AppEasing.emphasizedDecelerate),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
