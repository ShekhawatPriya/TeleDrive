import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/project/github_release_models.dart';
import 'package:flutter_m_fsdk/features/project/release_notes.dart';

void main() {
  final releases = GithubRelease.parseList(
    jsonDecode(File('test/fixtures/github_releases.json').readAsStringSync()),
  );
  final v313 = ReleaseNotes(
    releases.firstWhere((r) => r.tagName == 'v3.1.3').body,
  );

  test('sections keep their kinds and duplicate comparisons collapse', () {
    expect(v313.sections.map((s) => s.kind), [
      ReleaseSectionKind.notes,
      ReleaseSectionKind.changes,
      ReleaseSectionKind.contributors,
    ]);
    expect(v313.comparisonLinks, [
      'https://github.com/ShekhawatPriya/TeleDrive/compare/v3.1.2...v3.1.3',
    ]);
  });

  test('a bold lead becomes the highlight label', () {
    final first = v313.sections.first.highlights.first;
    expect(first.label, 'Photos and library');
    expect(first.text, startsWith('Refined library browsing'));
    expect(ReleaseHighlight.parse('**Theme**: system colors').label, 'Theme');
    expect(ReleaseHighlight.parse('Plain **bold** note').label, isNull);
  });

  test('generated pull request and contributor lines are structured', () {
    final change = v313.sections[1].changes.single!;
    expect(change.title, startsWith('Release 3.1.3: account'));
    expect(change.author, 'SreejanPersonal');
    expect(change.number, 1);
    final person = v313.sections[2].contributors.single!;
    expect(person.handle, 'SreejanPersonal');
    expect(person.number, 1);
    expect(ReleaseChange.parse('Just a sentence.'), isNull);
  });

  test('links read as short labels', () {
    expect(linkLabel('https://github.com/o/r/pull/12'), '#12');
    expect(
      linkLabel('https://github.com/o/r/compare/v1.0...v1.1'),
      'v1.0 → v1.1',
    );
    expect(linkLabel('https://www.example.com/docs/a/b'), 'example.com/docs/a');
  });

  test('preview prefers notes, then pull request titles', () {
    expect(v313.preview, startsWith('Photos and library: refined'));
    expect(
      ReleaseNotes(
        "## What's Changed\n* Fix uploads by @a in https://github.com/o/r/pull/9",
      ).preview,
      'Fix uploads',
    );
  });
}
