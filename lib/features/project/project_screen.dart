import 'package:flutter/cupertino.dart';
import '../../widgets/ios/ios_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/social_icons.dart';
import 'changelog_controller.dart';

part 'project_screen_cards.dart';
part 'project_screen_developer.dart';
part 'project_screen_header.dart';
part 'project_screen_ios.dart';

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
    final latest = changelog.latest;

    final changelogSubtitle = latest != null
        ? 'Latest ${latest.tagName} · full version history'
        : 'Release notes and version history';

    if (theme.platform == TargetPlatform.iOS)
      return _buildIosProject(context, changelogSubtitle);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Project'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const _ProjectHeader(),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Source & releases'),
          const SizedBox(height: AppSpacing.sm),
          _CategoryCard(
            icon: GitHubIcon(size: 22, color: scheme.primary),
            title: 'Open Source',
            subtitle: 'TeleDrive is free and open on GitHub',
            trailing: _CardTrailing.external,
            onTap: AppConfig.openRepository,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CategoryCard(
            icon: Icon(Icons.history_rounded, size: 22, color: scheme.primary),
            title: 'Changelog',
            subtitle: changelogSubtitle,
            trailing: _CardTrailing.chevron,
            onTap: () => context.push('/settings/project/changelog'),
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
            icon: Icon(Icons.shield_outlined, size: 22, color: scheme.primary),
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
              'Made with care · TeleDrive',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
