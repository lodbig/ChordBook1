// Feature: chordbook-app, Property 3: Chord Parser Round-Trip
//
// For any valid chord-embedded text string, parsing it into ChordBlocks and
// then reconstructing the original string should produce the original input.

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/domain/chord_parser.dart';

void main() {
  group('ChordParser – unit tests', () {
    test('parses line with leading text before first chord', () {
      final blocks = ChordParser.parseLine('מ[Am]חר [G]בבוקר');
      expect(blocks.length, 3);
      expect(blocks[0], ChordBlock(chord: '', text: 'מ'));
      expect(blocks[1], ChordBlock(chord: 'Am', text: 'חר '));
      expect(blocks[2], ChordBlock(chord: 'G', text: 'בבוקר'));
    });

    test('parses line starting with a chord', () {
      final blocks = ChordParser.parseLine('[Am]שלום [G]עולם');
      expect(blocks.length, 2);
      expect(blocks[0], ChordBlock(chord: 'Am', text: 'שלום '));
      expect(blocks[1], ChordBlock(chord: 'G', text: 'עולם'));
    });

    test('parses line with no chords', () {
      final blocks = ChordParser.parseLine('שורה ללא אקורדים');
      expect(blocks.length, 1);
      expect(blocks[0], ChordBlock(chord: '', text: 'שורה ללא אקורדים'));
    });

    test('parses empty line', () {
      final blocks = ChordParser.parseLine('');
      expect(blocks.length, 1);
      expect(blocks[0], ChordBlock(chord: '', text: ''));
    });

    test('parses line with only a chord', () {
      final blocks = ChordParser.parseLine('[C]');
      expect(blocks.length, 1);
      expect(blocks[0], ChordBlock(chord: 'C', text: ''));
    });

    test('isHeader returns true for ## prefix', () {
      expect(ChordParser.isHeader('## כותרת'), isTrue);
      expect(ChordParser.isHeader('##כותרת'), isTrue);
    });

    test('isHeader returns false for non-header lines', () {
      expect(ChordParser.isHeader('שורה רגילה'), isFalse);
      expect(ChordParser.isHeader('# לא כותרת'), isFalse);
      expect(ChordParser.isHeader(''), isFalse);
    });

    test('parseText splits by newlines', () {
      final result = ChordParser.parseText('[Am]שורה ראשונה\n[G]שורה שנייה');
      expect(result.length, 2);
      expect(result[0][0].chord, 'Am');
      expect(result[1][0].chord, 'G');
    });

    test('reconstructLine restores original string', () {
      const original = 'מ[Am]חר [G]בבוקר';
      final blocks = ChordParser.parseLine(original);
      expect(ChordParser.reconstructLine(blocks), original);
    });

    test('reconstructLine with no chords', () {
      const original = 'שורה ללא אקורדים';
      final blocks = ChordParser.parseLine(original);
      expect(ChordParser.reconstructLine(blocks), original);
    });
  });

  // **Validates: Requirements 2.2, 2.3, 34.3**
  group('Property 3: ChordParser Round-Trip', () {
    // Helper: generates a variety of chord-embedded strings
    final testInputs = [
      '',
      'שורה פשוטה',
      '[Am]',
      '[Am]טקסט',
      'טקסט[Am]',
      'מ[Am]חר [G]בבוקר',
      '[C][G][Am][F]',
      '[Am]שלום [G]עולם [F]מה [C]שלומך',
      '## כותרת שיר',
      '## [Am]כותרת עם אקורד',
      '[Cmaj7]טקסט [G/B]עוד טקסט',
      '[F#m]ראשון [C#]שני [G#m]שלישי',
      'a[A]b[B]c[C]d[D]e[E]f[F]g[G]',
      '[Am7]אקורד עם ספרה [Gsus4]ו-sus',
      'line with [C] english [G] text',
    ];

    test('parseLine → reconstructLine is identity for all test inputs', () {
      for (final input in testInputs) {
        final blocks = ChordParser.parseLine(input);
        final reconstructed = ChordParser.reconstructLine(blocks);
        expect(
          reconstructed,
          input,
          reason: 'Round-trip failed for: "$input"',
        );
      }
    });

    test('parseText → reconstruct each line is identity', () {
      final multiLine = testInputs.join('\n');
      final lines = ChordParser.parseText(multiLine);
      final originalLines = multiLine.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final reconstructed = ChordParser.reconstructLine(lines[i]);
        expect(
          reconstructed,
          originalLines[i],
          reason: 'Round-trip failed for line $i: "${originalLines[i]}"',
        );
      }
    });

    test('round-trip holds for 100 generated inputs with varying chord counts', () {
      // Simulate property-based testing with a range of structured inputs
      final chords = ['C', 'Am', 'G', 'F', 'Dm', 'Em', 'G7', 'Cmaj7', 'F#m', 'C#'];
      final words = ['שלום', 'עולם', 'מחר', 'היום', 'hello', 'world', 'a', ''];

      for (int i = 0; i < 100; i++) {
        final chordCount = i % 5; // 0–4 chords per line
        final buffer = StringBuffer();

        for (int j = 0; j < chordCount; j++) {
          if (j == 0 && i % 3 == 0) {
            // Sometimes start with text before first chord
            buffer.write(words[i % words.length]);
          }
          buffer.write('[${chords[j % chords.length]}]');
          buffer.write(words[(i + j) % words.length]);
        }
        if (chordCount == 0) {
          buffer.write(words[i % words.length]);
        }

        final input = buffer.toString();
        final blocks = ChordParser.parseLine(input);
        final reconstructed = ChordParser.reconstructLine(blocks);
        expect(
          reconstructed,
          input,
          reason: 'Round-trip failed for generated input: "$input"',
        );
      }
    });
  });
}
