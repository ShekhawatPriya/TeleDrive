part of 'changelog_screen.dart';

class _ReleaseCard extends StatefulWidget {
  const _ReleaseCard({
    super.key,
    required this.release,
    required this.isLatest,
  });
  final GithubRelease release;
  final bool isLatest;
  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  late bool expanded = widget.isLatest;
  bool showDetails = false;

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final notes = ReleaseNotes(release.body);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (release.tagName.isNotEmpty &&
                release.title.isNotEmpty &&
                release.title != release.tagName)
              Text(
                release.tagName,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (widget.isLatest)
              Text(
                'Latest published',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (release.isPrerelease)
              Text(
                'Pre-release',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          release.title.isEmpty || release.title == release.tagName
              ? 'Version ${release.tagName.replaceFirst(RegExp(r'^v'), '')}'
              : release.title,
          style:
              (widget.isLatest
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (release.publishedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            DateFormat.yMMMd().format(release.publishedAt!.toLocal()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final disclosureIcon = Icon(
      expanded
          ? (ios ? CupertinoIcons.chevron_up : Icons.expand_less)
          : (ios ? CupertinoIcons.chevron_down : Icons.expand_more),
      size: 20,
      color: scheme.onSurfaceVariant,
    );
    final disclosure = MediaQuery.textScalerOf(context).scale(1) >= 1.5
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerRight, child: disclosureIcon),
              const SizedBox(height: 8),
              heading,
            ],
          )
        : Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 12),
              disclosureIcon,
            ],
          );
    return Container(
      decoration: BoxDecoration(
        color: widget.isLatest ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isLatest)
            Padding(padding: const EdgeInsets.all(20), child: heading)
          else if (ios)
            CupertinoButton(
              padding: const EdgeInsets.all(20),
              onPressed: () => setState(() => expanded = !expanded),
              child: Semantics(expanded: expanded, child: disclosure),
            )
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => expanded = !expanded),
                child: Semantics(
                  expanded: expanded,
                  button: true,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: disclosure,
                  ),
                ),
              ),
            ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notes.sections.isEmpty)
                    Text(
                      notes.comparisonLinks.isEmpty
                          ? 'No detailed notes were published for this release.'
                          : 'This release includes a code comparison. Detailed app changes were not published.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  for (final section in notes.sections.where(
                    (s) => !s.isTechnical,
                  )) ...[
                    const Divider(height: 24),
                    if (section.title.isNotEmpty) ...[
                      Text(
                        section.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _MarkdownBody(text: section.body),
                  ],
                  if (notes.sections.any((s) => s.isTechnical)) ...[
                    const Divider(height: 24),
                    if (ios)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.centerLeft,
                        onPressed: () =>
                            setState(() => showDetails = !showDetails),
                        child: Semantics(
                          expanded: showDetails,
                          child: Text(
                            showDetails
                                ? 'Hide release details'
                                : 'Build & documentation details',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => showDetails = !showDetails),
                          child: Semantics(
                            expanded: showDetails,
                            child: Text(
                              showDetails
                                  ? 'Hide release details'
                                  : 'Build & documentation details',
                            ),
                          ),
                        ),
                      ),
                    if (showDetails)
                      for (final section in notes.sections.where(
                        (s) => s.isTechnical,
                      )) ...[
                        const SizedBox(height: 12),
                        Text(
                          section.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MarkdownBody(text: section.body),
                      ],
                  ],
                  if (notes.comparisonLinks.isNotEmpty ||
                      release.htmlUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final url in notes.comparisonLinks)
                          _ReleaseLink(label: 'Compare changes', url: url),
                        if (release.htmlUrl.isNotEmpty)
                          _ReleaseLink(
                            label: 'Release on GitHub',
                            url: release.htmlUrl,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReleaseLink extends StatelessWidget {
  const _ReleaseLink({required this.label, required this.url});
  final String label, url;
  @override
  Widget build(BuildContext context) {
    void open() {
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        onPressed: open,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return TextButton(onPressed: open, child: Text(label));
  }
}

/// A deliberately small Markdown renderer for GitHub release bodies. It handles
/// the common subset that appears in changelogs — headings, `-`/`*` bullets,
/// and `**bold**` inline spans — without pulling in a markdown dependency.
class _MarkdownBody extends StatelessWidget {
  const _MarkdownBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = text.replaceAll('\r\n', '\n').split('\n');

    final widgets = <Widget>[];
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        continue;
      }

      // Headings (#, ##, ###).
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (headingMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: _InlineText(
              text: headingMatch.group(2)!,
              baseStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ),
        );
        continue;
      }

      // Bullets (-, *, +).
      final bulletMatch = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineText(
                    text: bulletMatch.group(1)!,
                    baseStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Plain paragraph line.
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _InlineText(
            text: trimmed,
            baseStyle: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// Renders a single line of text with `**bold**` and `` `code` `` inline spans.
class _InlineText extends StatefulWidget {
  const _InlineText({required this.text, required this.baseStyle});

  final String text;
  final TextStyle? baseStyle;

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  final _links = <TapGestureRecognizer>[];

  void _clearLinks() {
    for (final link in _links) {
      link.dispose();
    }
    _links.clear();
  }

  @override
  void dispose() {
    _clearLinks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearLinks();
    final text = widget.text;
    final baseStyle = widget.baseStyle;
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*([^*]+)\*\*|`([^`]+)`|\[([^\]]+)\]\((https?://[^\s)]+)\)|(https?://[^\s]+))',
    );
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final bold = match.group(2);
      final code = match.group(3);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (code != null) {
        spans.add(
          TextSpan(
            text: code,
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
          ),
        );
      } else {
        final url = match.group(5) ?? match.group(6)!;
        final uri = Uri.tryParse(url);
        final link = TapGestureRecognizer()
          ..onTap = () {
            if (uri != null &&
                (uri.scheme == 'https' || uri.scheme == 'http')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          };
        _links.add(link);
        spans.add(
          TextSpan(
            text:
                match.group(4) ??
                (uri?.path.contains('/compare/') == true
                    ? 'View full changelog'
                    : url),
            recognizer: link,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
