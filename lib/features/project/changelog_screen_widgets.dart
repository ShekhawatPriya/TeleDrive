part of 'changelog_screen.dart';

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.isLatest});

  final GithubRelease release;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final published = release.publishedAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TagChip(label: release.tagName, highlighted: isLatest),
              if (isLatest) ...[
                const SizedBox(width: 8),
                _StatusChip(label: 'Latest', color: scheme.primary),
              ],
              if (release.isPrerelease) ...[
                const SizedBox(width: 8),
                _StatusChip(label: 'Pre-release', color: scheme.tertiary),
              ],
              const Spacer(),
              if (published != null)
                Text(
                  DateFormat.yMMMd().format(published.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            release.displayTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (release.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _MarkdownBody(text: release.body),
          ],
          if (release.htmlUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _open(release.htmlUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View on GitHub'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = highlighted
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final fg = highlighted
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontFamily: 'JetBrains Mono',
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
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
class _InlineText extends StatelessWidget {
  const _InlineText({required this.text, required this.baseStyle});

  final String text;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*([^*]+)\*\*|`([^`]+)`)');
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
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
