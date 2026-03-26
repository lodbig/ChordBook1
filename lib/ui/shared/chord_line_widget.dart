import 'package:flutter/material.dart';

import '../../domain/chord_parser.dart';
import 'chord_block_widget.dart';

/// Renders one parsed line as a [Wrap] of [ChordBlockWidget]s.
///
/// Using [Wrap] ensures a chord block is never split across visual lines –
/// the chord always stays directly above its lyric text.
class ChordLineWidget extends StatelessWidget {
  const ChordLineWidget({
    super.key,
    required this.blocks,
    this.fontSize = 16.0,
    this.chordFontSize = 14.0,
    this.fontFamily,
  });

  final List<ChordBlock> blocks;
  final double fontSize;
  final double chordFontSize;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: blocks
          .map((b) => ChordBlockWidget(
                block: b,
                fontSize: fontSize,
                chordFontSize: chordFontSize,
                fontFamily: fontFamily,
              ))
          .toList(),
    );
  }
}
