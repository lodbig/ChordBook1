// Feature: chordbook-app
// Property 9: Transpose Semitone Shift
// Property 10: Transpose 12-Semitone Round-Trip

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/domain/transpose_engine.dart';

void main() {
  group('TransposeEngine – unit tests', () {
    test('transposeChord shifts Am by 2 → Bm', () {
      expect(TransposeEngine.transposeChord('Am', 2), 'Bm');
    });

    test('transposeChord shifts C by 0 → C', () {
      expect(TransposeEngine.transposeChord('C', 0), 'C');
    });

    test('transposeChord shifts B by 1 → C (wraps around)', () {
      expect(TransposeEngine.transposeChord('B', 1), 'C');
    });

    test('transposeChord shifts C by -1 → B (negative steps)', () {
      expect(TransposeEngine.transposeChord('C', -1), 'B');
    });

    test('transposeChord preserves suffix: Am7 + 2 → Bm7', () {
      expect(TransposeEngine.transposeChord('Am7', 2), 'Bm7');
    });

    test('transposeChord preserves maj7 suffix', () {
      expect(TransposeEngine.transposeChord('Cmaj7', 2), 'Dmaj7');
    });

    test('transposeChord preserves sus4 suffix', () {
      expect(TransposeEngine.transposeChord('Gsus4', 1), 'G#sus4');
    });

    test('transposeChord handles slash chord: G/B + 2 → A/C#', () {
      expect(TransposeEngine.transposeChord('G/B', 2), 'A/C#');
    });

    test('transposeChord handles empty string', () {
      expect(TransposeEngine.transposeChord('', 5), '');
    });

    test('transposeText replaces all chords in text', () {
      const input = '[Am]שלום [G]עולם';
      final result = TransposeEngine.transposeText(input, 2);
      expect(result, '[Bm]שלום [A]עולם');
    });

    test('transposeText with 0 steps returns original', () {
      const input = '[Am]שלום [G]עולם';
      expect(TransposeEngine.transposeText(input, 0), input);
    });

    test('getDiatonicChords returns 7 chords for Am', () {
      final chords = TransposeEngine.getDiatonicChords('Am');
      expect(chords.length, 7);
      expect(chords, contains('Am'));
      expect(chords, contains('C'));
      expect(chords, contains('G'));
    });

    test('getDiatonicChords returns 7 chords for C major', () {
      final chords = TransposeEngine.getDiatonicChords('C');
      expect(chords.length, 7);
      expect(chords, contains('C'));
      expect(chords, contains('F'));
      expect(chords, contains('G'));
    });

    test('getDiatonicChords returns empty list for unknown key', () {
      expect(TransposeEngine.getDiatonicChords('X'), isEmpty);
    });
  });

  // **Validates: Requirements 14.8**
  group('Property 10: Transpose 12-Semitone Round-Trip', () {
    // All chromatic roots
    final roots = TransposeEngine.chromaticScale;
    // Common suffixes
    final suffixes = ['', 'm', '7', 'maj7', 'm7', 'sus4', 'dim', 'aug'];

    test('transposing any chord by 12 semitones returns the original chord', () {
      for (final root in roots) {
        for (final suffix in suffixes) {
          final chord = '$root$suffix';
          final result = TransposeEngine.transposeChord(chord, 12);
          expect(
            result,
            chord,
            reason: 'Round-trip failed for chord: "$chord"',
          );
        }
      }
    });

    test('transposing by -12 semitones also returns the original chord', () {
      for (final root in roots) {
        for (final suffix in suffixes) {
          final chord = '$root$suffix';
          final result = TransposeEngine.transposeChord(chord, -12);
          expect(
            result,
            chord,
            reason: 'Negative round-trip failed for chord: "$chord"',
          );
        }
      }
    });

    test('transposing by 24 semitones returns the original chord', () {
      for (final root in roots) {
        final chord = '${root}m';
        expect(
          TransposeEngine.transposeChord(chord, 24),
          chord,
          reason: 'Double octave round-trip failed for: "$chord"',
        );
      }
    });

    test('transposeText round-trip: 12 semitones restores original text', () {
      final testTexts = [
        '[Am]שלום [G]עולם',
        '[C]first [F]second [G]third',
        '[F#m]אקורד [C#]עם [G#m]דיאז',
        '[Cmaj7]מורכב [G/B]עם [Am7]ספרות',
      ];

      for (final text in testTexts) {
        final result = TransposeEngine.transposeText(text, 12);
        expect(
          result,
          text,
          reason: 'Text round-trip failed for: "$text"',
        );
      }
    });
  });

  // **Validates: Requirements 14.2, 14.3, 14.4, 14.5**
  group('Property 9: Transpose Semitone Shift Correctness', () {
    test('each chord root shifts by exactly N semitones in chromatic scale', () {
      final scale = TransposeEngine.chromaticScale;

      // Test all roots with steps 1–11
      for (int steps = 1; steps <= 11; steps++) {
        for (int i = 0; i < scale.length; i++) {
          final root = scale[i];
          final expectedIdx = (i + steps) % 12;
          final expected = scale[expectedIdx];

          final result = TransposeEngine.transposeChord(root, steps);
          expect(
            result,
            expected,
            reason: 'Chord $root + $steps steps should be $expected, got $result',
          );
        }
      }
    });

    test('suffix is preserved after transposition for all roots and steps', () {
      final scale = TransposeEngine.chromaticScale;
      const suffix = 'm7';

      for (int steps = 0; steps <= 12; steps++) {
        for (final root in scale) {
          final chord = '$root$suffix';
          final result = TransposeEngine.transposeChord(chord, steps);
          expect(
            result.endsWith(suffix),
            isTrue,
            reason: 'Suffix "$suffix" not preserved: "$chord" + $steps → "$result"',
          );
        }
      }
    });

    test('transposeText shifts every chord in text by exactly N semitones', () {
      // Verify each chord in the text is shifted correctly
      const text = '[C]do [D]re [E]mi [F]fa [G]sol [A]la [B]si';
      const steps = 3;
      final result = TransposeEngine.transposeText(text, steps);

      // C+3=D#, D+3=F, E+3=G, F+3=G#, G+3=A#, A+3=C, B+3=D
      expect(result, '[D#]do [F]re [G]mi [G#]fa [A#]sol [C]la [D]si');
    });

    test('negative steps shift chords backwards correctly', () {
      // Am - 2 = Gm
      expect(TransposeEngine.transposeChord('Am', -2), 'Gm');
      // C - 1 = B
      expect(TransposeEngine.transposeChord('C', -1), 'B');
      // F - 5 = C
      expect(TransposeEngine.transposeChord('F', -5), 'C');
    });

    test('large step values are handled via modulo 12', () {
      // 14 steps = 2 steps
      expect(
        TransposeEngine.transposeChord('C', 14),
        TransposeEngine.transposeChord('C', 2),
      );
      // -14 steps = -2 steps = 10 steps
      expect(
        TransposeEngine.transposeChord('C', -14),
        TransposeEngine.transposeChord('C', 10),
      );
    });
  });
}
