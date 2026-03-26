/// Represents a single block of chord + text.
/// [chord] is empty if there is no chord before this text segment.
class ChordBlock {
  final String chord;
  final String text;

  const ChordBlock({required this.chord, required this.text});

  @override
  String toString() => 'ChordBlock(chord: "$chord", text: "$text")';

  @override
  bool operator ==(Object other) =>
      other is ChordBlock && other.chord == chord && other.text == text;

  @override
  int get hashCode => Object.hash(chord, text);
}

class ChordParser {
  static final _chordRegex = RegExp(r'\[([^\]]*)\]');

  /// Parses a single line into a list of [ChordBlock]s.
  ///
  /// Example: "מ[Am]חר [G]בבוקר"
  /// → [{chord:"", text:"מ"}, {chord:"Am", text:"חר "}, {chord:"G", text:"בבוקר"}]
  static List<ChordBlock> parseLine(String line) {
    final matches = _chordRegex.allMatches(line).toList();

    if (matches.isEmpty) {
      return [ChordBlock(chord: '', text: line)];
    }

    final blocks = <ChordBlock>[];

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final chord = match.group(1) ?? '';

      // Text before this chord (only for the first match)
      if (i == 0 && match.start > 0) {
        blocks.add(ChordBlock(chord: '', text: line.substring(0, match.start)));
      }

      // Text after this chord, up to the next chord (or end of line)
      final textStart = match.end;
      final textEnd = (i + 1 < matches.length) ? matches[i + 1].start : line.length;
      final text = line.substring(textStart, textEnd);

      blocks.add(ChordBlock(chord: chord, text: text));
    }

    return blocks;
  }

  /// Parses a full multi-line text into a list of lines, each being a list of [ChordBlock]s.
  static List<List<ChordBlock>> parseText(String text) {
    return text.split('\n').map(parseLine).toList();
  }

  /// Returns true if the line is a header (starts with ##).
  static bool isHeader(String line) => line.startsWith('##');

  /// Reconstructs the original text from a list of [ChordBlock]s.
  /// This is the inverse of [parseLine] – used for round-trip verification.
  static String reconstructLine(List<ChordBlock> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block.chord.isNotEmpty) {
        buffer.write('[${block.chord}]');
      }
      buffer.write(block.text);
    }
    return buffer.toString();
  }
}
