part of 'project_screen.dart';

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.primaryContainer,
                  child: Icon(
                    Icons.cloud_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'TeleDrive',
            style:
                (largeText
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                      letterSpacing: -0.5,
                    ),
          ),
          const SizedBox(height: 6),
          Text(
            'A little more space. A lot more possibility.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Version ${AppConfig.appVersion}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
