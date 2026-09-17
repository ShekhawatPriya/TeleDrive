import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import 'legal_data.dart';
import '../../widgets/native_glass_button.dart';

enum LegalKind { privacy, terms }

class LegalScreen extends StatefulWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalKind kind;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalKind _selectedKind;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.kind;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kind != oldWidget.kind) _select(widget.kind);
  }

  void _select(LegalKind kind) {
    if (kind == _selectedKind) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _selectedKind = kind);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final privacy = _selectedKind == LegalKind.privacy;
    final title = privacy ? 'Privacy Policy' : 'Terms of Service';
    final sections = privacy ? privacySections : termsSections;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Legal',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        toolbarHeight: 56,
        leading: theme.platform == TargetPlatform.iOS
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: NativeGlassButton(
                  label: 'Back',
                  symbol: 'chevron.left',
                  icon: CupertinoIcons.chevron_back,
                  size: 40,
                  symbolSize: 17,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              )
            : BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: CupertinoSlidingSegmentedControl<LegalKind>(
                    groupValue: _selectedKind,
                    backgroundColor: scheme.surfaceContainerLow,
                    thumbColor: CupertinoDynamicColor.resolve(
                      const CupertinoDynamicColor.withBrightness(
                        color: Colors.white,
                        darkColor: Color(0xFF3A3A3C),
                      ),
                      context,
                    ),
                    padding: const EdgeInsets.all(3),
                    onValueChanged: (kind) {
                      if (kind != null) _select(kind);
                    },
                    children: {
                      for (final kind in LegalKind.values)
                        kind: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            kind == LegalKind.privacy ? 'Privacy' : 'Terms',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: kind == _selectedKind
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: kind == _selectedKind
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    },
                  ),
                ),
                Expanded(
                  child: SelectionArea(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            16,
                            24,
                            32 + MediaQuery.paddingOf(context).bottom,
                          ),
                          sliver: SliverList.list(
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1.15,
                                    letterSpacing: -.8,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Last updated: May 2026',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              for (var i = 0; i < sections.length; i++)
                                _LegalSection(
                                  section: sections[i],
                                  number: i + 1,
                                ),
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
                      ],
                    ),
                  ),
                ),
              ],
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
