part of '../free_up_space_screen.dart';

class _FreeUpExplanationCard extends StatelessWidget {
  const _FreeUpExplanationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _FreeUpSectionCard(
      title: 'What gets removed',
      subtitle: 'Local gallery copies only — your cloud stays untouched',
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.05),
            borderRadius: AppRadii.mdR,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_done_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'TeleDrive removes the local gallery copy from this phone only. Your backed-up copy remains available in TeleDrive.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Never touched',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _FreeUpIconRow(
          icon: Icons.upload_file_outlined,
          text: 'Manual uploads',
        ),
        const _FreeUpIconRow(
          icon: Icons.sync_rounded,
          text: 'Files still uploading',
        ),
        const _FreeUpIconRow(
          icon: Icons.error_outline_rounded,
          text: 'Failed backups',
        ),
        const _FreeUpIconRow(
          icon: Icons.cloud_off_outlined,
          text: 'Items not found in cloud',
        ),
        const _FreeUpIconRow(
          icon: Icons.folder_off_outlined,
          text: 'Anything outside Auto Backup',
          isLast: true,
        ),
      ],
    );
  }
}

class _FreeUpSectionCard extends StatelessWidget {
  const _FreeUpSectionCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _FreeUpIconRow extends StatelessWidget {
  const _FreeUpIconRow({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeUpMetricRow extends StatelessWidget {
  const _FreeUpMetricRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
