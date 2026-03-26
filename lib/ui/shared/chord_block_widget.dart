import 'package:flutter/material.dart';

import '../../domain/chord_parser.dart';
import '../../app/theme.dart';

/// Renders a single [ChordBlock] as a Column:
///   chord text (top, colored)
///   lyric text (bottom)
///
/// If [block.chord] is empty, a transparent placeholder of [chordFontSize] height
/// is shown so all blocks in a line stay vertically aligned.
class ChordBlockWidget extends StatelessWidget {
  const ChordBlockWidget({
    super.key,
    required this.block,
    this.fontSize = 16.0,
    this.chordFontSize = 14.0,
    this.fontFamily,
  });

  final ChordBlock block;
  final double fontSize;
  final double chordFontSize;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final chordColor =
        Theme.of(context).extension<ChordBookColors>()?.chordColor ??
            Colors.amber;

    final chordWidget = block.chord.isNotEmpty
        ? Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              block.chord,
              style: TextStyle(
                fontSize: chordFontSize,
                fontWeight: FontWeight.bold,
                color: chordColor,
                height: 1.2,
                fontFamily: fontFamily,
              ),
            ),
          )
        : SizedBox(height: chordFontSize * 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        chordWidget,
        Text(
          block.text,
          style: TextStyle(fontSize: fontSize, height: 1.4, fontFamily: fontFamily),
        ),
      ],
    );
  }
}
