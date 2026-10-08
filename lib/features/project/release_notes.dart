/// Presentation structure for published notes. Headings come from the author;
/// the client never guesses features or rewrites their meaning.
class ReleaseNotesSection {
  const ReleaseNotesSection(this.title, this.body);
  final String title;
  final String body;
  bool get isTechnical => const [
    'release',
    'documentation',
    'build',
    'builds',
  ].contains(title.toLowerCase());
}

class ReleaseNotes {
  ReleaseNotes(String body) {
    var title = '';
    var lines = <String>[];
    void flush() {
      final content = lines.join('\n').trim();
      if (content.isNotEmpty) sections.add(ReleaseNotesSection(title, content));
      lines = [];
    }

    var fenced = false;
    for (final line in body.replaceAll('\r\n', '\n').split('\n')) {
      if (line.trimLeft().startsWith('```')) fenced = !fenced;
      final heading = fenced
          ? null
          : RegExp(r'^#{1,6}\s+(.+)$').firstMatch(line.trim());
      if (heading != null) {
        flush();
        title = heading.group(1)!;
      } else if (RegExp(
        r'^\*\*Full Changelog\*\*:\s*https://',
      ).hasMatch(line.trim())) {
        final url = RegExp(r'https://\S+').firstMatch(line)?.group(0);
        if (url != null && !comparisonLinks.contains(url))
          comparisonLinks.add(url);
      } else {
        lines.add(line);
      }
    }
    flush();
  }
  final sections = <ReleaseNotesSection>[];
  final comparisonLinks = <String>[];

  String get preview {
    for (final section in sections.where((section) => !section.isTechnical)) {
      for (final line in section.body.split('\n')) {
        final text = line
            .trim()
            .replaceFirst(RegExp(r'^[-*+]\s+'), '')
            .replaceAllMapped(
              RegExp(r'\[([^\]]+)\]\([^)]*\)'),
              (m) => m.group(1)!,
            )
            .replaceAll('**', '')
            .replaceAll('`', '');
        if (text.isNotEmpty) return text;
      }
    }
    return 'Detailed notes are available on GitHub.';
  }
}
