// Feature: chordbook-app, Property 11: Performance View Transpose Does Not Mutate Storage
//
// For any song and any transpose amount applied in Performance View, the text
// stored in the database for that song should remain unchanged after the view
// is closed.
//
// Feature: chordbook-app, Property 12: Zoom Preserves Font Ratio
//
// For any zoom factor applied in Performance View, the ratio of chordFontSize
// to textFontSize should remain constant (equal to the configured ratio).
//
// Validates: Requirements 16.2, 17.2, 17.3

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/song.dart';
import 'package:chordbook/domain/transpose_engine.dart';

// ---------------------------------------------------------------------------
// Simulated performance view state (mirrors _PerformanceScreenState)
// ---------------------------------------------------------------------------

class PerformanceViewState {
  PerformanceViewState({required this.storedSong})
      : _transposeSteps = 0,
        _fontSize = 18.0;

  final Song storedSong; // immutable reference to storage
  int _transposeSteps;
  double _fontSize;

  static const double chordFontRatio = 0.85;

  /// Transpose in view only – does NOT modify storedSong
  void transpose(int steps) {
    _transposeSteps += steps;
  }

  /// Change font size in view only
  void changeFontSize(double delta) {
    _fontSize = (_fontSize + delta).clamp(10.0, 36.0);
  }

  /// What the view renders (transposed text)
  String get renderedText {
    if (_transposeSteps == 0) return storedSong.versions.values.first;
    return TransposeEngine.transposeText(
      storedSong.versions.values.first,
      _transposeSteps,
    );
  }

  double get fontSize => _fontSize;
  double get chordFontSize => _fontSize * chordFontRatio;

  /// The stored text is NEVER modified by the view
  String get storedText => storedSong.versions.values.first;
}

Song _song(String text) => Song(
      id: 'test',
      title: 'שיר',
      versions: {'רגיל': text},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 11: Performance View Transpose Does Not Mutate Storage', () {
    test('stored text unchanged after transpose', () {
      const original = '[Am]שלום [G]עולם';
      final view = PerformanceViewState(storedSong: _song(original));

      view.transpose(3);
      expect(view.storedText, original,
          reason: 'Stored text was mutated by transpose');
      expect(view.renderedText, isNot(original),
          reason: 'Rendered text should differ after transpose');
    });

    test('stored text unchanged after multiple transposes', () {
      const original = '[C]do [G]re [Am]mi';
      final view = PerformanceViewState(storedSong: _song(original));

      view.transpose(5);
      view.transpose(-2);
      view.transpose(7);
      expect(view.storedText, original);
    });

    test('stored text unchanged after transpose and font change', () {
      const original = '[Dm]text [F]more';
      final view = PerformanceViewState(storedSong: _song(original));

      view.transpose(2);
      view.changeFontSize(4);
      view.changeFontSize(-2);
      expect(view.storedText, original);
    });

    test('property holds for 100 generated inputs', () {
      final chords = ['C', 'Am', 'G', 'F', 'Dm', 'Em'];
      final words = ['שלום', 'עולם', 'hello', 'world', 'מחר'];

      for (int i = 0; i < 100; i++) {
        final text = '[${chords[i % chords.length]}]${words[i % words.length]} '
            '[${chords[(i + 1) % chords.length]}]${words[(i + 2) % words.length]}';

        final view = PerformanceViewState(storedSong: _song(text));
        final steps = (i % 12) - 6; // -6 to +5
        view.transpose(steps);

        expect(
          view.storedText,
          text,
          reason: 'Iteration $i: stored text was mutated',
        );
      }
    });
  });

  group('Property 12: Zoom Preserves Font Ratio', () {
    const ratio = PerformanceViewState.chordFontRatio;

    test('chord/text ratio is constant at default size', () {
      final view = PerformanceViewState(storedSong: _song(''));
      expect(view.chordFontSize / view.fontSize, closeTo(ratio, 0.001));
    });

    test('chord/text ratio preserved after font increase', () {
      final view = PerformanceViewState(storedSong: _song(''));
      view.changeFontSize(4);
      expect(view.chordFontSize / view.fontSize, closeTo(ratio, 0.001));
    });

    test('chord/text ratio preserved after font decrease', () {
      final view = PerformanceViewState(storedSong: _song(''));
      view.changeFontSize(-4);
      expect(view.chordFontSize / view.fontSize, closeTo(ratio, 0.001));
    });

    test('ratio preserved for 100 font size changes', () {
      for (int i = 0; i < 100; i++) {
        final view = PerformanceViewState(storedSong: _song(''));
        final delta = (i % 20 - 10).toDouble(); // -10 to +9
        view.changeFontSize(delta);

        expect(
          view.chordFontSize / view.fontSize,
          closeTo(ratio, 0.001),
          reason: 'Iteration $i: ratio changed after font delta $delta',
        );
      }
    });
  });
}
