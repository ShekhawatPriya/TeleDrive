import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../widgets/brand_mark.dart';
import '../../core/utils/safe_navigation.dart';
import '../../core/theme/ios_palette.dart';
import '../../widgets/ios/ios_page.dart';
import '../../widgets/sheet/adaptive_sheet.dart';
import 'components/how_it_works_section.dart';
import 'components/landing_collection_art.dart';
import 'components/privacy_and_trust_section.dart';
import 'components/storage_separation_section.dart';

/// A focused introduction. Detailed storage and privacy explanations are
/// available before sign-in without competing with the primary action.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (theme.platform == TargetPlatform.iOS) return const _IosLanding();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                Row(
                  children: [
                    const BrandMark(size: 36),
                    const SizedBox(width: 12),
                    Text('TeleDrive', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 28),
                const LandingCollectionArt(),
                const SizedBox(height: 28),
                Semantics(
                  header: true,
                  child: Text(
                    'Life, collected.',
                    style: theme.textTheme.displayMedium?.copyWith(
                      letterSpacing: -1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A home for your photos, files and everything worth keeping. Connected to your Telegram.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.safePush('/login'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue with Telegram'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        theme.platform == TargetPlatform.iOS ? 28 : 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You will need access to your Telegram account to sign in.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 32),
                const _Feature(
                  icon: Icons.folder_outlined,
                  title: 'Make space for your files',
                  detail:
                      'Keep documents in folders and favorites within reach.',
                ),
                const _Feature(
                  icon: Icons.photo_library_outlined,
                  title: 'Keep your memories together',
                  detail: 'Browse photos and choose what to back up.',
                ),
                const _Feature(
                  icon: Icons.link_rounded,
                  title: 'Share on your terms',
                  detail: 'Create links and revoke access when you need to.',
                ),
                const SizedBox(height: 24),
                Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    title: const Text('How your data is stored'),
                    subtitle: const Text('Storage, privacy and your control'),
                    childrenPadding: const EdgeInsets.all(20),
                    children: const [
                      HowItWorksSection(),
                      SizedBox(height: 24),
                      StorageSeparationSection(),
                      SizedBox(height: 24),
                      PrivacyAndTrustSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => context.safePush('/privacy'),
                      child: const Text('Privacy'),
                    ),
                    TextButton(
                      onPressed: () => context.safePush('/terms'),
                      child: const Text('Terms'),
                    ),
                    TextButton(
                      onPressed: AppConfig.openRepository,
                      child: const Text('Source code'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Apple's welcome-screen pattern, composed with the app's grouped cards: the
/// real app icon and a large title, the three things TeleDrive does as one
/// inset group, and the primary action pinned above the home indicator with
/// the storage explanation and policies beneath it.
class _IosLanding extends StatelessWidget {
  const _IosLanding();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = TextStyle(
      fontSize: 13,
      letterSpacing: -.1,
      color: scheme.onSurfaceVariant,
    );
    // At large text sizes the actions scroll with the page, so the pinned
    // footer never crowds out the content on a small phone.
    final large = MediaQuery.textScalerOf(context).scale(17) > 26;
    final footer = Padding(
      padding: EdgeInsets.fromLTRB(large ? 0 : 20, 8, large ? 0 : 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoButton.filled(
            minimumSize: const Size.fromHeight(54),
            borderRadius: BorderRadius.circular(100),
            onPressed: () => context.safePush('/login'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.paperplane_fill, size: 19),
                SizedBox(width: 9),
                Flexible(
                  child: Text(
                    'Continue with Telegram',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 10),
            onPressed: () => _showStorageExplanation(context),
            child: const Text(
              'How TeleDrive Stores Your Data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, letterSpacing: -.2),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FooterLink(
                label: 'Privacy Policy',
                onTap: () => context.safePush('/privacy'),
              ),
              Text('·', style: secondary),
              _FooterLink(
                label: 'Terms',
                onTap: () => context.safePush('/terms'),
              ),
              Text('·', style: secondary),
              const _FooterLink(
                label: 'Source Code',
                onTap: AppConfig.openRepository,
              ),
            ],
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (box.maxHeight - 40).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: _AppIcon(size: 92)),
                            const SizedBox(height: 26),
                            Semantics(
                              header: true,
                              child: Text(
                                'Welcome to TeleDrive',
                                textScaler: MediaQuery.textScalerOf(
                                  context,
                                ).clamp(maxScaleFactor: 1.35),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'CupertinoSystemDisplay',
                                  fontSize: 34,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.6,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Your photos and files in one calm place, '
                                'kept in your own Telegram.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 1.4,
                                  letterSpacing: -.4,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            const IosGroup(
                              bottomSpacing: 0,
                              dividerInset: 66,
                              children: [
                                _IosFeature(
                                  icon: CupertinoIcons.folder_fill,
                                  color: IosTint.documents,
                                  title: 'Room for Your Files',
                                  detail:
                                      'Folders, favorites and search for '
                                      'everything you keep.',
                                ),
                                _IosFeature(
                                  icon: CupertinoIcons
                                      .photo_fill_on_rectangle_fill,
                                  color: IosTint.photos,
                                  title: 'Your Memories, Together',
                                  detail:
                                      'Browse your library and choose what '
                                      'to back up.',
                                ),
                                _IosFeature(
                                  icon: CupertinoIcons.link,
                                  color: IosTint.freeUpSpace,
                                  title: 'Share on Your Terms',
                                  detail:
                                      'Create links and revoke access '
                                      'whenever you need to.',
                                ),
                              ],
                            ),
                            if (large) ...[const SizedBox(height: 24), footer],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!large) footer,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStorageExplanation(BuildContext context) => showAdaptiveSheet<void>(
    context: context,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HowItWorksSection(),
          SizedBox(height: 24),
          StorageSeparationSection(),
          SizedBox(height: 24),
          PrivacyAndTrustSection(),
        ],
      ),
    ),
  );
}

/// The installed app icon with the system's continuous corners.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .2237);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: Image.asset(
            'assets/icon/app_icon_ios.png',
            width: size,
            height: size,
            cacheWidth: (size * 3).round(),
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    minimumSize: const Size(44, 44),
    onPressed: onTap,
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        letterSpacing: -.1,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A feature as a Settings-style row: a tinted symbol tile, a title and one
/// line of detail.
class _IosFeature extends StatelessWidget {
  const _IosFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final CupertinoDynamicColor color;
  final String title, detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: color.resolveFrom(context),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: SizedBox.square(
                dimension: 38,
                child: Icon(icon, size: 21, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.32,
                    letterSpacing: -.15,
                    color: scheme.onSurfaceVariant,
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
