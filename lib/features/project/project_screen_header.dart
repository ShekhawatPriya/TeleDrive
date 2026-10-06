part of 'project_screen.dart';

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Image.asset(
            'assets/icon/app_icon.png',
            width: 72,
            height: 72,
            excludeFromSemantics: true,
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
            'Your files, photos, and videos.\nConnected through Telegram.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Installed version ${AppConfig.appVersion}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
