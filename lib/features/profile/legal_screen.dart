import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/social_icons.dart';
import 'legal_data.dart';

enum LegalKind { privacy, terms }

class LegalScreen extends StatefulWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalKind kind;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalKind _selectedKind;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.kind;
    _pageController = PageController(initialPage: widget.kind.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kind != oldWidget.kind) {
      setState(() {
        _selectedKind = widget.kind;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          widget.kind.index,
          duration: AppDurations.medium3,
          curve: AppEasing.emphasizedDecelerate,
        );
      }
    }
  }

  void _handleSelectionChanged(Set<LegalKind> selection) {
    if (selection.isEmpty) return;
    final target = selection.first;
    setState(() {
      _selectedKind = target;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target.index,
        duration: AppDurations.medium3,
        curve: AppEasing.emphasizedDecelerate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final title = _selectedKind == LegalKind.privacy
        ? 'Privacy Policy'
        : 'Terms of Service';

    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<LegalKind>(
              segments: const [
                ButtonSegment<LegalKind>(
                  value: LegalKind.privacy,
                  label: Text('Privacy Policy'),
                  icon: Icon(Icons.privacy_tip_outlined, size: 18),
                ),
                ButtonSegment<LegalKind>(
                  value: LegalKind.terms,
                  label: Text('Terms of Service'),
                  icon: Icon(Icons.description_outlined, size: 18),
                ),
              ],
              selected: {_selectedKind},
              onSelectionChanged: _handleSelectionChanged,
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: GitHubIcon(
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    label: const Text(
                      'Open Source Project',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => AppConfig.openRepository(),
                  ),
                ),
                Text(
                  'Last updated: May 2026',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedKind = LegalKind.values[index];
                });
              },
              children: [
                _LegalList(sections: privacySections),
                _LegalList(sections: termsSections),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalList extends StatelessWidget {
  const _LegalList({required this.sections});

  final List<SectionContent> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        return _LegalSectionCard(sections[index]);
      },
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard(this.section);

  final SectionContent section;

  IconData _iconForSection(String title) {
    final t = title.toLowerCase();
    if (t.contains('overview')) return Icons.info_outline_rounded;
    if (t.contains('collect')) {
      if (t.contains('not')) return Icons.gpp_good_outlined;
      return Icons.analytics_outlined;
    }
    if (t.contains('security') || t.contains('keychain'))
      return Icons.vpn_key_outlined;
    if (t.contains('cache') || t.contains('performance'))
      return Icons.speed_rounded;
    if (t.contains('permission') || t.contains('media'))
      return Icons.photo_library_outlined;
    if (t.contains('store')) return Icons.cloud_done_outlined;
    if (t.contains('transparency') || t.contains('license'))
      return Icons.code_rounded;
    if (t.contains('control')) return Icons.tune_rounded;
    if (t.contains('contact')) return Icons.mail_outline_rounded;
    if (t.contains('acceptance')) return Icons.assignment_turned_in_outlined;
    if (t.contains('description')) return Icons.dashboard_customize_outlined;
    if (t.contains('account')) return Icons.person_outline_rounded;
    if (t.contains('limit') || t.contains('api')) return Icons.gavel_rounded;
    if (t.contains('warranty') || t.contains('backup'))
      return Icons.backup_outlined;
    if (t.contains('change')) return Icons.update_rounded;
    if (t.contains('termination')) return Icons.cancel_presentation_rounded;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sectionIcon = _iconForSection(section.title);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: section.title.toLowerCase().contains('open source')
                      ? GitHubIcon(size: 20, color: scheme.primary)
                      : Icon(sectionIcon, size: 20, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (section.paragraph != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  section.paragraph!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (section.bullets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final item in section.bullets) _BulletItem(item),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
