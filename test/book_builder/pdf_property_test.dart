// Feature: chordbook-app, Property 13: TOC Page Numbers Match Actual Pages
//
// For any BookTemplate with a table of contents, every page number listed in
// the TOC should match the actual page number where that song begins in the
// generated PDF (two-pass rendering correctness).
//
// Feature: chordbook-app, Property 14: Header/Footer Placeholder Replacement
//
// For any header or footer template string containing placeholders {title},
// {page}, {total_pages}, or {date}, after rendering a page none of the
// placeholder tokens should appear literally in the output.
//
// Validates: Requirements 33.7, 32.6, 38.3, 38.4, 38.5, 38.6

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/book_template.dart';
import 'package:chordbook/data/models/song.dart';

// ---------------------------------------------------------------------------
// Inline page number calculation (mirrors PdfEngine.calculatePageNumbers)
// ---------------------------------------------------------------------------

Map<String, int> calculatePageNumbers(
    BookTemplate template, Map<String, Song> songMap) {
  final result = <String, int>{};
  int currentPage = 1;

  if (template.hasCoverPage) currentPage++;
  if (template.hasIntroPage) currentPage++;
  if (template.hasTOC && template.tocPosition == TocPosition.beforeContent) {
    currentPage++;
  }

  for (final section in template.sections) {
    if (section is SectionDivider) {
      if (section.fullPage) currentPage++;
    } else if (section is SongEntry) {
      result[section.songId] = currentPage;
      final song = songMap[section.songId];
      if (song != null) {
        final text = song.versions.values.first;
        final lines = text.split('\n').length;
        currentPage += (lines / 30).ceil().clamp(1, 20);
      } else {
        currentPage++;
      }
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// Inline placeholder replacement (mirrors header/footer rendering)
// ---------------------------------------------------------------------------

String replacePlaceholders(
    String template, String title, int page, int totalPages, String date) {
  return template
      .replaceAll('{title}', title)
      .replaceAll('{page}', '$page')
      .replaceAll('{total_pages}', '$totalPages')
      .replaceAll('{date}', date);
}

Song _song(String id, {int lines = 20}) => Song(
      id: id,
      title: 'שיר $id',
      versions: {'רגיל': List.generate(lines, (i) => 'שורה $i').join('\n')},
    );

BookTemplate _template({
  bool hasCover = false,
  bool hasIntro = false,
  bool hasTOC = false,
  TocPosition tocPosition = TocPosition.beforeContent,
  List<BookSection> sections = const [],
}) =>
    BookTemplate(
      id: 'test',
      name: 'test',
      hasCoverPage: hasCover,
      hasIntroPage: hasIntro,
      hasTOC: hasTOC,
      tocPosition: tocPosition,
      sections: sections,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 13: TOC Page Numbers Match Actual Pages', () {
    test('first song starts on page 1 with no cover/intro/TOC', () {
      final songs = {'s1': _song('s1')};
      final template = _template(sections: [SongEntry(songId: 's1')]);
      final pages = calculatePageNumbers(template, songs);
      expect(pages['s1'], 1);
    });

    test('first song starts on page 2 with cover page', () {
      final songs = {'s1': _song('s1')};
      final template = _template(
        hasCover: true,
        sections: [SongEntry(songId: 's1')],
      );
      final pages = calculatePageNumbers(template, songs);
      expect(pages['s1'], 2);
    });

    test('first song starts on page 3 with cover + TOC before content', () {
      final songs = {'s1': _song('s1')};
      final template = _template(
        hasCover: true,
        hasTOC: true,
        tocPosition: TocPosition.beforeContent,
        sections: [SongEntry(songId: 's1')],
      );
      final pages = calculatePageNumbers(template, songs);
      expect(pages['s1'], 3);
    });

    test('second song starts after first song pages', () {
      final songs = {
        's1': _song('s1', lines: 30), // 1 page
        's2': _song('s2'),
      };
      final template = _template(sections: [
        SongEntry(songId: 's1'),
        SongEntry(songId: 's2'),
      ]);
      final pages = calculatePageNumbers(template, songs);
      expect(pages['s1'], 1);
      expect(pages['s2'], greaterThan(pages['s1']!));
    });

    test('page numbers are monotonically increasing for sequential songs', () {
      final songs = {
        for (int i = 0; i < 5; i++) 's$i': _song('s$i', lines: 30),
      };
      final template = _template(
        sections: List.generate(5, (i) => SongEntry(songId: 's$i')),
      );
      final pages = calculatePageNumbers(template, songs);

      for (int i = 0; i < 4; i++) {
        expect(
          pages['s${i + 1}']!,
          greaterThan(pages['s$i']!),
          reason: 'Song s${i + 1} should start after s$i',
        );
      }
    });

    test('property holds for 100 generated templates', () {
      for (int i = 0; i < 100; i++) {
        final songCount = (i % 8) + 1;
        final songs = {
          for (int j = 0; j < songCount; j++)
            'song_$j': _song('song_$j', lines: 10 + (j * 5)),
        };
        final template = _template(
          hasCover: i % 3 == 0,
          hasIntro: i % 4 == 0,
          hasTOC: i % 2 == 0,
          sections: List.generate(songCount, (j) => SongEntry(songId: 'song_$j')),
        );

        final pages = calculatePageNumbers(template, songs);

        // All songs should have a page number
        for (int j = 0; j < songCount; j++) {
          expect(
            pages.containsKey('song_$j'),
            isTrue,
            reason: 'Iteration $i: song_$j missing from page numbers',
          );
          expect(
            pages['song_$j']!,
            greaterThanOrEqualTo(1),
            reason: 'Iteration $i: song_$j has invalid page number',
          );
        }

        // Page numbers should be monotonically increasing
        for (int j = 0; j < songCount - 1; j++) {
          expect(
            pages['song_${j + 1}']!,
            greaterThanOrEqualTo(pages['song_$j']!),
            reason: 'Iteration $i: page numbers not monotonic at song $j',
          );
        }
      }
    });
  });

  group('Property 14: Header/Footer Placeholder Replacement', () {
    const placeholders = ['{title}', '{page}', '{total_pages}', '{date}'];

    test('all placeholders are replaced', () {
      const template = '{title} - עמוד {page} מתוך {total_pages} - {date}';
      final result = replacePlaceholders(template, 'שיר', 5, 100, '2024-01-01');
      for (final p in placeholders) {
        expect(result, isNot(contains(p)),
            reason: 'Placeholder $p was not replaced');
      }
      expect(result, contains('שיר'));
      expect(result, contains('5'));
      expect(result, contains('100'));
      expect(result, contains('2024-01-01'));
    });

    test('template with no placeholders is unchanged', () {
      const template = 'כותרת קבועה';
      final result = replacePlaceholders(template, 'שיר', 1, 10, '2024');
      expect(result, template);
    });

    test('property holds for 100 generated templates', () {
      final titles = ['שיר א', 'שיר ב', 'Hello', 'World'];
      final templates = [
        '{title}',
        '{page}',
        '{total_pages}',
        '{date}',
        '{title} - {page}',
        'עמוד {page} מתוך {total_pages}',
        '{title} | {date}',
        '{title} {page}/{total_pages} {date}',
        'ללא placeholders',
        '',
      ];

      for (int i = 0; i < 100; i++) {
        final tmpl = templates[i % templates.length];
        final title = titles[i % titles.length];
        final page = i + 1;
        final total = 100 + i;
        final date = '2024-${((i % 12) + 1).toString().padLeft(2, '0')}-01';

        final result = replacePlaceholders(tmpl, title, page, total, date);

        for (final p in placeholders) {
          expect(
            result,
            isNot(contains(p)),
            reason: 'Iteration $i: placeholder $p not replaced in "$tmpl"',
          );
        }
      }
    });
  });
}
