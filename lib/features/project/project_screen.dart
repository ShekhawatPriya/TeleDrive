import 'package:flutter/cupertino.dart';
import '../../widgets/ios/ios_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'github_release_models.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/social_icons.dart';
import 'changelog_controller.dart';

part 'project_screen_cards.dart';
part 'project_screen_developer.dart';
part 'project_screen_header.dart';
part 'project_screen_ios.dart';
part 'project_release_preview.dart';

class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({super.key});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  @override
  void initState() {
    super.initState();
    // Warm the changelog so the card can surface the latest version. Cached,
    // so opening the changelog screen later reuses this result.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(changelogControllerProvider).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final changelog = ref.watch(changelogControllerProvider).state;

    if (theme.platform == TargetPlatform.iOS)
      return _buildIosProject(context, changelog);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('About TeleDrive'),
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 48),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ProjectHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionLabel('Source & releases'),
                  const SizedBox(height: AppSpacing.sm),
                  _ProjectReleasePreview(
                    state: changelog,
                    onRetry: () =>
                        ref.read(changelogControllerProvider).load(force: true),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryCard(
                    icon: GitHubIcon(size: 22, color: scheme.primary),
                    title: 'Open Source',
                    subtitle: 'TeleDrive is free and open on GitHub',
                    trailing: _CardTrailing.external,
                    onTap: AppConfig.openRepository,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionLabel('The story'),
                  const SizedBox(height: AppSpacing.sm),
                  const _AboutCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionLabel('The maker'),
                  const SizedBox(height: AppSpacing.sm),
                  const _DeveloperCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionLabel('Legal'),
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryCard(
                    icon: Icon(
                      Icons.shield_outlined,
                      size: 22,
                      color: scheme.primary,
                    ),
                    title: 'Privacy Policy',
                    subtitle: 'How TeleDrive handles your data',
                    onTap: () => context.push('/privacy'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryCard(
                    icon: Icon(
                      Icons.description_outlined,
                      size: 22,
                      color: scheme.primary,
                    ),
                    title: 'Terms of Service',
                    subtitle: 'Rules for using TeleDrive',
                    onTap: () => context.push('/terms'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Text(
                      'Made with care. Built to be yours.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
