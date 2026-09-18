part of 'project_screen.dart';

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (largeText)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MakerPortrait(),
                SizedBox(height: AppSpacing.md),
                _MakerIdentity(),
              ],
            )
          else
            const Row(
              children: [
                _MakerPortrait(),
                SizedBox(width: AppSpacing.md),
                Expanded(child: _MakerIdentity()),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Building tools that make powerful tech feel effortless. '
            'Thanks for making TeleDrive part of your day.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SocialLinks(),
        ],
      ),
    );
  }
}

class _MakerPortrait extends StatelessWidget {
  const _MakerPortrait();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/icon/devsdocode.png',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          color: scheme.primaryContainer,
          child: Text(
            'S',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _MakerIdentity extends StatelessWidget {
  const _MakerIdentity();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Made by Sree',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'An independent DevsDoCode project',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SocialLinks extends StatelessWidget {
  const _SocialLinks();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final links = <({String label, Widget icon, VoidCallback onTap})>[
      (
        label: 'GitHub',
        icon: GitHubIcon(size: 20, color: scheme.onSurface),
        onTap: AppConfig.openRepository,
      ),
      (
        label: 'Instagram',
        icon: InstagramIcon(size: 20, color: scheme.onSurface),
        onTap: AppConfig.openInstagram,
      ),
      (
        label: 'X',
        icon: XIcon(size: 18, color: scheme.onSurface),
        onTap: AppConfig.openTwitter,
      ),
      (
        label: 'YouTube',
        icon: YouTubeIcon(size: 20, color: scheme.onSurface),
        onTap: AppConfig.openYouTube,
      ),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final link in links)
          _SocialLink(icon: link.icon, label: link.label, onTap: link.onTap),
      ],
    );
  }
}

class _SocialLink extends StatelessWidget {
  const _SocialLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      key: ValueKey('project-social-${label.toLowerCase()}'),
      button: true,
      label: 'Open $label',
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 20, height: 20, child: Center(child: icon)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    softWrap: false,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
