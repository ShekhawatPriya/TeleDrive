part of 'project_screen.dart';

Widget _buildIosProject(BuildContext context, ChangelogState changelog) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final text = theme.textTheme;
  return IosPage(
    title: 'About TeleDrive',
    compact: true,
    horizontalPadding: 20,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        child: Column(
          children: [
            Image.asset(
              'assets/icon/app_icon.png',
              width: 88,
              height: 88,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 12),
            Text(
              'TeleDrive',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A little more space.\nA lot more possibility.',
              style: text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text('Version ${AppConfig.appVersion}', style: text.bodySmall),
          ],
        ),
      ),
      _ProjectReleasePreview(
        state: changelog,
        onRetry: () => ProviderScope.containerOf(
          context,
        ).read(changelogControllerProvider).load(force: true),
      ),
      const SizedBox(height: 12),
      _AboutDestination(
        icon: CupertinoIcons.chevron_left_slash_chevron_right,
        title: 'Built in the Open',
        subtitle: 'Explore the code on GitHub',
        external: true,
        onTap: AppConfig.openRepository,
      ),
      const SizedBox(height: 36),
      Text('Your files. Your space.', style: text.headlineSmall),
      const SizedBox(height: 12),
      Text(
        'TeleDrive brings your files, photos, and videos together, with your Telegram account at the heart of it. A familiar home for the things you want to keep.',
        style: text.bodyLarge?.copyWith(
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 32),
      Divider(height: 1, color: scheme.outlineVariant),
      const SizedBox(height: 28),
      Row(
        children: [
          ClipRSuperellipse(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/icon/devsdocode.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Made by Sree', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'An independent DevsDoCode project',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'Building tools that make powerful tech feel effortless. Thanks for making TeleDrive part of your day.',
        style: text.bodyMedium?.copyWith(height: 1.5),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _AboutSocial(
            label: 'GitHub',
            icon: GitHubIcon(size: 18, color: scheme.onSurface),
            onTap: AppConfig.openRepository,
          ),
          _AboutSocial(
            label: 'Instagram',
            icon: InstagramIcon(size: 18, color: scheme.onSurface),
            onTap: AppConfig.openInstagram,
          ),
          _AboutSocial(
            label: 'X',
            icon: XIcon(size: 18, color: scheme.onSurface),
            onTap: AppConfig.openTwitter,
          ),
          _AboutSocial(
            label: 'YouTube',
            icon: YouTubeIcon(size: 18, color: scheme.onSurface),
            onTap: AppConfig.openYouTube,
          ),
        ],
      ),
      const SizedBox(height: 32),
      Divider(height: 1, color: scheme.outlineVariant),
      _AboutLegalLink(
        label: 'Privacy Policy',
        onTap: () => context.push('/privacy'),
      ),
      Divider(height: 1, color: scheme.outlineVariant),
      _AboutLegalLink(
        label: 'Terms of Service',
        onTap: () => context.push('/terms'),
      ),
      Divider(height: 1, color: scheme.outlineVariant),
      const SizedBox(height: 28),
      Text(
        'Made with care. Built to be yours.',
        textAlign: TextAlign.center,
        style: text.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _AboutDestination extends StatelessWidget {
  const _AboutDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool external;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(24),
      child: CupertinoButton(
        color: scheme.surfaceContainerLow,
        padding: const EdgeInsets.all(18),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, size: 24, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              external
                  ? CupertinoIcons.arrow_up_right
                  : CupertinoIcons.chevron_right,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSocial extends StatelessWidget {
  const _AboutSocial({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    onPressed: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

/// Quiet footer navigation; chevrons and full-width targets distinguish these
/// destinations from the noninteractive signature below.
class _AboutLegalLink extends StatelessWidget {
  const _AboutLegalLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
