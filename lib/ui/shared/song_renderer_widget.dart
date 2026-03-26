import 'package:flutter/material.dart';

import '../../domain/chord_parser.dart';
import '../../domain/transpose_engine.dart';
import 'chord_line_widget.dart';

/// Renders a full song text (with `[chord]` syntax) as a scrollable column.
///
/// - Lines starting with `##` are rendered as bold headers.
/// - Empty lines become vertical spacing.
/// - All other lines are rendered via [ChordLineWidget].
/// - [transposeSteps] shifts all chords before rendering (does not mutate storage).
class SongRendererWidget extends StatelessWidget {
  const SongRendererWidget({
    super.key,
    required this.text,
    this.transposeSteps = 0,
    this.fontSize = 16.0,
    this.chordFontSize = 14.0,
    this.padding = const EdgeInsets.all(16),
    this.fontFamily,
  });

  final String text;
  final int transposeSteps;
  final double fontSize;
  final double chordFontSize;
  final EdgeInsets padding;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final displayText = transposeSteps != 0
        ? TransposeEngine.transposeText(text, transposeSteps)
        : text;

    final lines = displayText.split('\n');

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines.map((line) => _buildLine(context, line)).toList(),
      ),
    );
  }

  Widget _buildLine(BuildContext context, String line) {
    // Empty line → spacing
    if (line.trim().isEmpty) {
      return SizedBox(height: fontSize * 0.8);
    }

    // Header line (## prefix)
    if (ChordParser.isHeader(line)) {
      final headerText = line.replaceFirst(RegExp(r'^##\s*'), '');
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          headerText,
          style: TextStyle(
            fontSize: fontSize * 1.4,
            fontWeight: FontWeight.bold,
            height: 1.3,
            fontFamily: fontFamily,
          ),
        ),
      );
    }

    // Normal chord line
    final blocks = ChordParser.parseLine(line);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ChordLineWidget(
        blocks: blocks,
        fontSize: fontSize,
        chordFontSize: chordFontSize,
        fontFamily: fontFamily,
      ),
    );
  }
}
