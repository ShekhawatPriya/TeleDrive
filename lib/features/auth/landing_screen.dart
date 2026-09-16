import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../widgets/brand_mark.dart';
import '../../core/utils/safe_navigation.dart';
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
