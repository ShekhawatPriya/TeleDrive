import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/ios_palette.dart';
import 'legal_data.dart';
import '../../widgets/ios/ios_page.dart';

enum LegalKind { privacy, terms }

/// A single legal document. Privacy Policy and Terms of Service are separate
/// pages, each titled after its document.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalKind kind;

  bool get _privacy => kind == LegalKind.privacy;
  String get _title => _privacy ? 'Privacy Policy' : 'Terms of Service';
  List<SectionContent> get _sections =>
      _privacy ? privacySections : termsSections;

  static const _lastUpdated = 'Last updated: May 2026';

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _buildIos(context);
    }
    return _buildMaterial(context);
  }

  Widget _buildIos(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IosPage(
      title: _title,
      compact: true,
      children: [
        IosSettingsIntro(
          icon: _privacy
              ? CupertinoIcons.hand_raised_fill
              : CupertinoIcons.doc_text_fill,
          color: _privacy ? IosTint.privacy : IosTint.neutral,
          title: _title,
          description: _privacy
              ? 'What TeleDrive accesses, what it stores and why. Your files stay in your own Telegram account.'
              : 'The rules for using TeleDrive, an open-source client for storing files in your own Telegram account.',
        ),
        SelectionArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _lastUpdated,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _sections.length; i++)
                  _LegalSection(section: _sections[i], number: i + 1),
              ],
            ),
          ),
        ),
        IosGroup(
          children: [
            IosRow(
              title: 'Open Source Project',
              subtitle: 'View the repository',
              icon: CupertinoIcons.chevron_left_slash_chevron_right,
              color: IosTint.neutral,
              trailing: Icon(
                CupertinoIcons.arrow_up_right,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              onTap: AppConfig.openRepository,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        toolbarHeight: 56,
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SelectionArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Text(
                    _lastUpdated,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  for (var i = 0; i < _sections.length; i++)
                    _LegalSection(section: _sections[i], number: i + 1),
                  const SizedBox(height: 4),
                  Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      title: const Text('Open Source Project'),
                      subtitle: const Text('View the repository'),
                      trailing: const Icon(
                        CupertinoIcons.arrow_up_right,
                        size: 18,
                      ),
                      onTap: AppConfig.openRepository,
                    ),
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

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.section, required this.number});

  final SectionContent section;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.65,
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SECTION ${number.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            section.title,
            style: TextStyle(
              fontSize: 19,
              height: 1.35,
              letterSpacing: -.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (section.paragraph != null) ...[
          const SizedBox(height: 12),
          Text(section.paragraph!, style: bodyStyle),
        ],
        for (final bullet in section.bullets)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Text(
                    '•',
                    style: bodyStyle.copyWith(color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(bullet, style: bodyStyle)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ],
    );
  }
}
