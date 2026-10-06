import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/project/release_notes.dart';

void main() {
  test('preserves author categories and keeps technical copy separate', () {
    final notes = ReleaseNotes(
      'Intro\r\n\r\n## Photos\r\n- Keep **aspect ratio**.\r\n\r\n## Release\r\nBuild 7.',
    );
    expect(notes.sections.map((s) => s.title), ['', 'Photos', 'Release']);
    expect(notes.sections.last.isTechnical, isTrue);
    expect(notes.sections[1].body, '- Keep **aspect ratio**.');
    expect(notes.preview, 'Intro');
  });
  test('comparison-only release does not invent feature notes', () {
    final notes = ReleaseNotes(
      '**Full Changelog**: https://github.com/a/b/compare/v1...v2\n\n**Full Changelog**: https://github.com/a/b/compare/v1...v2',
    );
    expect(notes.sections, isEmpty);
    expect(notes.comparisonLinks, hasLength(1));
    expect(notes.preview, 'Detailed notes are available on GitHub.');
  });
  test('preview keeps linked feature text and skips packaging', () {
    final notes = ReleaseNotes(
      '## Release\nBuild 7.\n## Sharing\n- Use [Share a copy](https://example.com) with `files`.',
    );
    expect(notes.preview, 'Use Share a copy with files.');
  });
  test('empty notes remain empty and headings inside code stay intact', () {
    expect(ReleaseNotes('').sections, isEmpty);
    final notes = ReleaseNotes('## Notes\n```\n# not a section\n```');
    expect(notes.sections, hasLength(1));
    expect(notes.sections.single.body, contains('# not a section'));
  });
}
