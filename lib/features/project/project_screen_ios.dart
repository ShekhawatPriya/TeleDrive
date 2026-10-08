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
      const _ProjectHeader(),
      const SizedBox(height: 20),
      _ProjectReleasePreview(
        state: changelog,
        onRetry: () => ProviderScope.containerOf(
          context,
        ).read(changelogControllerProvider).load(force: true),
      ),
      const SizedBox(height: 32),
      Text(
        'Your library, connected',
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      const _AboutCard(),
      const SizedBox(height: 32),
      Text(
        'The maker',
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
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
      IosGroup(
        title: 'PROJECT & POLICIES',
        children: [
          IosRow(
            title: 'Source code',
            subtitle: 'Explore TeleDrive on GitHub',
            leading: GitHubIcon(size: 22, color: scheme.primary),
            trailing: Icon(
              CupertinoIcons.arrow_up_right,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            onTap: AppConfig.openRepository,
          ),
          IosRow(
            title: 'Privacy Policy',
            subtitle: 'How TeleDrive handles your data',
            onTap: () => context.push('/privacy'),
          ),
          IosRow(
            title: 'Terms of Service',
            subtitle: 'Rules for using TeleDrive',
            onTap: () => context.push('/terms'),
          ),
        ],
      ),
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
