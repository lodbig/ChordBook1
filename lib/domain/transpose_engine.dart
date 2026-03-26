class TransposeEngine {
  static const List<String> chromaticScale = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  // Regex to match a chord root: letter A-G followed by optional # or b
  static final _rootRegex = RegExp(r'^([A-G][#b]?)(.*)$');
  static final _chordInTextRegex = RegExp(r'\[([^\]]*)\]');

  /// Transposes a single chord name by [steps] semitones.
  /// Preserves suffix (m, 7, maj7, sus4, /E, etc.).
  ///
  /// Example: transposeChord("Am", 2) → "Bm"
  static String transposeChord(String chord, int steps) {
    if (chord.isEmpty) return chord;

    // Handle slash chords: split on '/' and transpose both parts
    final slashIdx = chord.indexOf('/');
    if (slashIdx > 0) {
      final base = chord.substring(0, slashIdx);
      final bass = chord.substring(slashIdx + 1);
      final transposedBase = transposeChord(base, steps);
      final transposedBass = transposeChord(bass, steps);
      return '$transposedBase/$transposedBass';
    }

    final match = _rootRegex.firstMatch(chord);
    if (match == null) return chord;

    final root = match.group(1)!;
    final suffix = match.group(2)!;

    // Normalize flat to sharp equivalent
    final normalizedRoot = _flatToSharp(root);
    final idx = chromaticScale.indexOf(normalizedRoot);
    if (idx == -1) return chord;

    final newIdx = ((idx + steps) % 12 + 12) % 12;
    return chromaticScale[newIdx] + suffix;
  }

  /// Transposes all chords embedded in [text] by [steps] semitones.
  static String transposeText(String text, int steps) {
    if (steps == 0) return text;
    return text.replaceAllMapped(_chordInTextRegex, (match) {
      final chord = match.group(1) ?? '';
      return '[${transposeChord(chord, steps)}]';
    });
  }

  /// Returns the diatonic chords for a given key.
  /// Supports: Am, C, G, D, E, F, Dm, Em and their relative keys.
  static List<String> getDiatonicChords(String key) {
    const diatonicMap = <String, List<String>>{
      // Minor keys (natural minor: i, ii°, III, iv, v, VI, VII)
      'Am': ['Am', 'Bdim', 'C', 'Dm', 'Em', 'F', 'G'],
      'Em': ['Em', 'F#dim', 'G', 'Am', 'Bm', 'C', 'D'],
      'Dm': ['Dm', 'Edim', 'F', 'Gm', 'Am', 'A#', 'C'],
      'Gm': ['Gm', 'Adim', 'A#', 'Cm', 'Dm', 'D#', 'F'],
      'Cm': ['Cm', 'Ddim', 'D#', 'Fm', 'Gm', 'G#', 'A#'],
      'Fm': ['Fm', 'Gdim', 'G#', 'A#m', 'Cm', 'C#', 'D#'],
      'Bm': ['Bm', 'C#dim', 'D', 'Em', 'F#m', 'G', 'A'],
      'F#m': ['F#m', 'G#dim', 'A', 'Bm', 'C#m', 'D', 'E'],
      'C#m': ['C#m', 'D#dim', 'E', 'F#m', 'G#m', 'A', 'B'],
      'G#m': ['G#m', 'A#dim', 'B', 'C#m', 'D#m', 'E', 'F#'],
      'D#m': ['D#m', 'Fdim', 'F#', 'G#m', 'A#m', 'B', 'C#'],
      'A#m': ['A#m', 'Cdim', 'C#', 'D#m', 'Fm', 'F#', 'G#'],
      // Major keys (I, ii, iii, IV, V, vi, vii°)
      'C':  ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim'],
      'G':  ['G', 'Am', 'Bm', 'C', 'D', 'Em', 'F#dim'],
      'D':  ['D', 'Em', 'F#m', 'G', 'A', 'Bm', 'C#dim'],
      'A':  ['A', 'Bm', 'C#m', 'D', 'E', 'F#m', 'G#dim'],
      'E':  ['E', 'F#m', 'G#m', 'A', 'B', 'C#m', 'D#dim'],
      'B':  ['B', 'C#m', 'D#m', 'E', 'F#', 'G#m', 'A#dim'],
      'F':  ['F', 'Gm', 'Am', 'A#', 'C', 'Dm', 'Edim'],
      'F#': ['F#', 'G#m', 'A#m', 'B', 'C#', 'D#m', 'E#dim'],
      'C#': ['C#', 'D#m', 'Fm', 'F#', 'G#', 'A#m', 'Cdim'],
      'G#': ['G#', 'A#m', 'Cm', 'C#', 'D#', 'Fm', 'Gdim'],
      'D#': ['D#', 'Fm', 'Gm', 'G#', 'A#', 'Cm', 'Ddim'],
      'A#': ['A#', 'Cm', 'Dm', 'D#', 'F', 'Gm', 'Adim'],
    };

    return diatonicMap[key] ?? [];
  }

  /// Converts flat notation to sharp equivalent for lookup.
  static String _flatToSharp(String note) {
    const flatToSharp = {
      'Db': 'C#',
      'Eb': 'D#',
      'Fb': 'E',
      'Gb': 'F#',
      'Ab': 'G#',
      'Bb': 'A#',
      'Cb': 'B',
    };
    return flatToSharp[note] ?? note;
  }
}
