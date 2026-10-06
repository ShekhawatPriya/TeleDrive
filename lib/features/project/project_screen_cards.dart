part of 'project_screen.dart';

enum _CardTrailing { chevron, external }

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = _CardTrailing.chevron,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final _CardTrailing trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CategoryIcon(icon: icon),
                          _CategoryTrailingIcon(trailing: trailing),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryCopy(title: title, subtitle: subtitle),
                    ],
                  )
                : Row(
                    children: [
                      _CategoryIcon(icon: icon),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _CategoryCopy(title: title, subtitle: subtitle),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _CategoryTrailingIcon(trailing: trailing),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SizedBox(width: 22, height: 22, child: Center(child: icon)),
  );
}

class _CategoryCopy extends StatelessWidget {
  const _CategoryCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _CategoryTrailingIcon extends StatelessWidget {
  const _CategoryTrailingIcon({required this.trailing});

  final _CardTrailing trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return trailing == _CardTrailing.chevron
        ? Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          )
        : Icon(
            Icons.open_in_new_rounded,
            size: 18,
            color: scheme.primary.withValues(alpha: 0.7),
          );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    const points = <(IconData, String, String)>[
      (
        Icons.folder_outlined,
        'Your Telegram library',
        'Keep files, photos, and videos together in your Telegram account.',
      ),
      (
        Icons.lock_outline_rounded,
        'Direct file transfers',
        'Original files transfer directly between this device and Telegram. '
            'The service keeps your library metadata.',
      ),
      (
        Icons.star_outline_rounded,
        'Find, organise, share',
        'Browse folders, star favourites, share files, and switch between '
            'your saved accounts.',
      ),
    ];

    Widget point(int i) {
      final icon = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(points[i].$1, color: scheme.primary, size: 20),
      );
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            points[i].$2,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            points[i].$3,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      );
      if (MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [icon, const SizedBox(height: 12), copy],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: AppSpacing.md),
          Expanded(child: copy),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            point(i),
          ],
        ],
      ),
    );
  }
}
