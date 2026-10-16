/// Presentation structure for published notes. Headings come from the author;
/// the client never guesses features or rewrites their meaning.
enum ReleaseSectionKind {
  /// Author-written notes: highlights, feature areas, fixes.
  notes,

  /// GitHub's generated "What's Changed" list of merged pull requests.
  changes,

  /// GitHub's generated "New Contributors" list.
  contributors,

  /// Release, Build and Documentation details, shown behind a disclosure.
  technical,
}

class ReleaseNotesSection {
  const ReleaseNotesSection(this.title, this.body);
  final String title;
  final String body;

  bool get isTechnical => kind == ReleaseSectionKind.technical;

  ReleaseSectionKind get kind {
    final t = title.toLowerCase().replaceAll('’', "'").trim();
    if (const ['release', 'documentation', 'build', 'builds'].contains(t)) {
      return ReleaseSectionKind.technical;
    }
    if (t == "what's changed") return ReleaseSectionKind.changes;
    if (t == 'new contributors') return ReleaseSectionKind.contributors;
    return ReleaseSectionKind.notes;
  }

  /// The section as separate entries: each bullet (with its wrapped
  /// continuation lines) or paragraph is one item, Markdown markers removed.
  List<String> get items {
    final items = <String>[];
    var current = <String>[];
    void flush() {
      final text = current.join(' ').trim();
      if (text.isNotEmpty) items.add(text);
      current = [];
    }

    for (final raw in body.split('\n')) {
      final line = raw.trim();
      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
      if (line.isEmpty) {
        flush();
      } else if (bullet != null) {
        flush();
        current.add(bullet.group(1)!);
      } else {
        // A wrapped bullet line continues its bullet.
        current.add(line);
      }
    }
    flush();
    return items;
  }

  List<ReleaseHighlight> get highlights =>
      items.map(ReleaseHighlight.parse).toList();

  /// Entries GitHub generated for merged pull requests. Lines that do not
  /// follow GitHub's wording are kept as plain highlights by the caller.
  List<ReleaseChange?> get changes => items.map(ReleaseChange.parse).toList();

  List<ReleaseContributor?> get contributors =>
      items.map(ReleaseContributor.parse).toList();
}

/// A note, optionally led by the author's bold label, as in
/// `**Photos and library:** refined library browsing`.
class ReleaseHighlight {
  const ReleaseHighlight({this.label, required this.text});
  final String? label;
  final String text;

  static ReleaseHighlight parse(String item) {
    final match = RegExp(
      r'^\*\*([^*]{1,48}?)(:?)\*\*(:?)\s*(.+)$',
    ).firstMatch(item);
    if (match == null || (match.group(2)!.isEmpty && match.group(3)!.isEmpty)) {
      return ReleaseHighlight(text: item);
    }
    final rest = match.group(4)!.trim();
    return ReleaseHighlight(
      label: match.group(1)!.trim(),
      text: rest.isEmpty ? rest : rest[0].toUpperCase() + rest.substring(1),
    );
  }
}

/// GitHub's generated `<title> by @author in <pull URL>` line.
class ReleaseChange {
  const ReleaseChange({
    required this.title,
    required this.url,
    this.author,
    this.number,
  });
  final String title;
  final String url;
  final String? author;
  final int? number;

  static ReleaseChange? parse(String item) {
    final match = RegExp(
      r'^(.+?)\s+by\s+@([A-Za-z0-9-]+(?:\[bot\])?)\s+in\s+(https://github\.com/\S+/(?:pull|issues)/(\d+))\s*$',
    ).firstMatch(item);
    if (match == null) return null;
    return ReleaseChange(
      title: match.group(1)!.trim(),
      author: match.group(2),
      url: match.group(3)!,
      number: int.tryParse(match.group(4)!),
    );
  }
}

/// GitHub's generated `@author made their first contribution in <URL>` line.
class ReleaseContributor {
  const ReleaseContributor({
    required this.handle,
    required this.url,
    this.number,
  });
  final String handle;
  final String url;
  final int? number;

  static ReleaseContributor? parse(String item) {
    final match = RegExp(
      r'^@([A-Za-z0-9-]+)\s+made\s+(?:their|his|her)\s+first\s+contribution\s+in\s+(https://github\.com/\S+/pull/(\d+))\s*$',
    ).firstMatch(item);
    if (match == null) return null;
    return ReleaseContributor(
      handle: match.group(1)!,
      url: match.group(2)!,
      number: int.tryParse(match.group(3)!),
    );
  }
}

/// The compared range of a GitHub compare URL, as `v3.1.2 → v3.1.3`.
String? compareRange(String url) {
  final match = RegExp(r'/compare/([^?#\s]+)').firstMatch(url);
  return match?.group(1)?.replaceFirst(RegExp(r'\.{2,3}'), ' → ');
}

/// A short label for a link in running text: `#12` for a pull request or
/// issue, the compared range for a comparison, otherwise the host and path.
String linkLabel(String url) {
  final number = RegExp(r'/(?:pull|issues)/(\d+)').firstMatch(url)?.group(1);
  if (number != null) return '#$number';
  final range = compareRange(url);
  if (range != null) return range;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final path = uri.pathSegments.where((s) => s.isNotEmpty).take(2).join('/');
  return path.isEmpty ? host : '$host/$path';
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
        if (url != null && !comparisonLinks.contains(url)) {
          comparisonLinks.add(url);
        }
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
      for (final item in section.items) {
        final change = section.kind == ReleaseSectionKind.changes
            ? ReleaseChange.parse(item)
            : null;
        if (section.kind == ReleaseSectionKind.contributors) break;
        final text = (change?.title ?? item)
            .replaceAllMapped(
              RegExp(r'\[([^\]]+)\]\([^)]*\)'),
              (m) => m.group(1)!,
            )
            .replaceAll('**', '')
            .replaceAll('`', '')
            .trim();
        if (text.isNotEmpty) return text;
      }
    }
    return 'Detailed notes are available on GitHub.';
  }
}
