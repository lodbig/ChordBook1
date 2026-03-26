import 'package:flutter/material.dart';

import '../../domain/chord_parser.dart';
import '../../app/theme.dart';

/// A song renderer where chords can be dragged to new positions within their line.
/// Dropping a chord onto a lyric block inserts [chord] before that block's text
/// in the raw ChordPro, so the chord appears above that word in the live view.
class DraggableSongRenderer extends StatefulWidget {
  const DraggableSongRenderer({
    super.key,
    required this.text,
    required this.onTextChanged,
    this.fontSize = 16.0,
    this.chordFontSize = 14.0,
    this.padding = const EdgeInsets.all(16),
  });

  final String text;
  final void Function(String newText) onTextChanged;
  final double fontSize;
  final double chordFontSize;
  final EdgeInsets padding;

  @override
  State<DraggableSongRenderer> createState() => _DraggableSongRendererState();
}

class _DraggableSongRendererState extends State<DraggableSongRenderer> {
  @override
  Widget build(BuildContext context) {
    final lines = widget.text.split('\n');

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(lines.length, (i) => _buildLine(context, lines[i], i)),
      ),
    );
  }

  Widget _buildLine(BuildContext context, String line, int lineIndex) {
    if (line.trim().isEmpty) {
      return SizedBox(height: widget.fontSize * 0.8);
    }
    if (ChordParser.isHeader(line)) {
      final headerText = line.replaceFirst(RegExp(r'^##\s*'), '');
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          headerText,
          style: TextStyle(fontSize: widget.fontSize * 1.4, fontWeight: FontWeight.bold, height: 1.3),
        ),
      );
    }

    final blocks = ChordParser.parseLine(line);

    // Compute the raw-text char offset for each block (position in line without [chord] tokens)
    // This tells us: if we drop onto block[i], insert [chord] at rawOffset[i] in the stripped line.
    final rawOffsets = _computeRawOffsets(blocks);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: List.generate(blocks.length, (bi) {
          return _DraggableBlock(
            block: blocks[bi],
            blockIndex: bi,
            lineIndex: lineIndex,
            rawOffset: rawOffsets[bi],
            fontSize: widget.fontSize,
            chordFontSize: widget.chordFontSize,
            onDrop: (dragData, targetRawOffset) => _handleDrop(dragData, lineIndex, targetRawOffset),
          );
        }),
      ),
    );
  }

  /// For each block, compute the character offset in the stripped line (no [chord] tokens)
  /// that corresponds to the start of block.text.
  List<int> _computeRawOffsets(List<ChordBlock> blocks) {
    final offsets = <int>[];
    int pos = 0;
    for (final b in blocks) {
      offsets.add(pos);
      pos += b.text.length;
    }
    return offsets;
  }

  void _handleDrop(_ChordDragData drag, int targetLineIndex, int targetRawOffset) {
    final lines = widget.text.split('\n');

    // Source line: remove the dragged [chord] token
    if (drag.lineIndex >= lines.length) return;
    final sourceLine = lines[drag.lineIndex];
    // Remove first occurrence of [chord] in source line
    final chordToken = '[${drag.chord}]';
    final sourceWithout = sourceLine.replaceFirst(chordToken, '');

    // Target line: insert [chord] at the raw offset
    // If source == target, work on the already-modified line
    final targetLineRaw = drag.lineIndex == targetLineIndex ? sourceWithout : lines[targetLineIndex];

    // Strip all [chord] tokens to get the plain text, find insertion point
    final stripped = targetLineRaw.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    final insertAt = targetRawOffset.clamp(0, stripped.length);

    // Now find the actual position in targetLineRaw that corresponds to insertAt in stripped
    final insertPosInRaw = _rawOffsetToFullOffset(targetLineRaw, insertAt);
    final newTargetLine = targetLineRaw.substring(0, insertPosInRaw) +
        chordToken +
        targetLineRaw.substring(insertPosInRaw);

    lines[drag.lineIndex] = sourceWithout;
    if (drag.lineIndex != targetLineIndex) {
      lines[targetLineIndex] = newTargetLine;
    } else {
      lines[drag.lineIndex] = newTargetLine;
    }

    widget.onTextChanged(lines.join('\n'));
  }

  /// Maps a char offset in the stripped text (no [chord] tokens) back to
  /// the corresponding offset in the full raw line.
  int _rawOffsetToFullOffset(String rawLine, int strippedOffset) {
    int stripped = 0;
    int i = 0;
    while (i < rawLine.length && stripped < strippedOffset) {
      if (rawLine[i] == '[') {
        // Skip over [chord] token
        final end = rawLine.indexOf(']', i);
        if (end != -1) {
          i = end + 1;
          continue;
        }
      }
      stripped++;
      i++;
    }
    // Skip any chord token at current position
    while (i < rawLine.length && rawLine[i] == '[') {
      final end = rawLine.indexOf(']', i);
      if (end != -1) { i = end + 1; } else break;
    }
    return i;
  }
}

// ---------------------------------------------------------------------------
// Draggable + drop-target block
// ---------------------------------------------------------------------------

class _DraggableBlock extends StatefulWidget {
  const _DraggableBlock({
    required this.block,
    required this.blockIndex,
    required this.lineIndex,
    required this.rawOffset,
    required this.fontSize,
    required this.chordFontSize,
    required this.onDrop,
  });

  final ChordBlock block;
  final int blockIndex;
  final int lineIndex;
  final int rawOffset;
  final double fontSize;
  final double chordFontSize;
  final void Function(_ChordDragData drag, int rawOffset) onDrop;

  @override
  State<_DraggableBlock> createState() => _DraggableBlockState();
}

class _DraggableBlockState extends State<_DraggableBlock> {
  bool _isHovered = false;
  final GlobalKey _textKey = GlobalKey();
  
  int? _hoverCharIndex;
  double? _caretX;

  void _updateHoverPosition(Offset globalOffset) {
    final ctx = _textKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPos = box.globalToLocal(globalOffset);
    
    // הגדרה קשיחה לעברית (ימין לשמאל)
    const textDirection = TextDirection.rtl;

    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.block.text.isEmpty ? ' ' : widget.block.text,
        style: TextStyle(fontSize: widget.fontSize, height: 1.4),
      ),
      textDirection: textDirection,
    );
    
    textPainter.layout(maxWidth: box.size.width > 0 ? box.size.width : double.infinity);

    // מציאת אינדקס האות הקרובה ביותר
    final textPosition = textPainter.getPositionForOffset(localPos);
    final charIndex = widget.block.text.isEmpty ? 0 : textPosition.offset.clamp(0, widget.block.text.length);

    // מציאת המיקום המדויק על ציר ה-X עבור הסמן
    final caretOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: charIndex),
      Rect.zero,
    );

    if (_hoverCharIndex != charIndex || _caretX != caretOffset.dx) {
      setState(() {
        _hoverCharIndex = charIndex;
        _caretX = caretOffset.dx;
      });
    }
  }

  void _clearHover() {
    setState(() {
      _isHovered = false;
      _hoverCharIndex = null;
      _caretX = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chordColor =
        Theme.of(context).extension<ChordBookColors>()?.chordColor ?? Colors.amber;

    // --- האקורד שמוצג לפני הגרירה ---
    final chordWidget = widget.block.chord.isNotEmpty
        ? Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              widget.block.chord,
              style: TextStyle(
                fontSize: widget.chordFontSize,
                fontWeight: FontWeight.bold,
                color: chordColor,
                height: 1.2,
              ),
            ),
          )
        : SizedBox(height: widget.chordFontSize * 1.2);

    // --- טקסט המילים עם סמן ה"בלון" ---
    final lyricWidget = Stack(
      clipBehavior: Clip.none, // מאפשר לסמן לגלוש ימינה/שמאלה מחוץ לגבולות המילה
      children: [
        Text(
          widget.block.text,
          key: _textKey,
          style: TextStyle(fontSize: widget.fontSize, height: 1.4),
        ),
        
        // ציור הבלון כשאנחנו מרחפים
        if (_isHovered && _caretX != null)
          Positioned(
            left: _caretX! - 6.0, // ממורכז לפי רוחב הבלון
            top: -12.0, // מרחף מעל האות
            bottom: 0,
            child: IgnorePointer( // כדי שהסמן לא יפריע לאירועי הגרירה
              child: Column(
                children: [
                  // ראש הבלון (עיגול קטן)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: chordColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ]
                    ),
                  ),
                  // חוט הבלון (הקו שיורד אל בין האותיות)
                  Expanded(
                    child: Container(
                      width: 2.0,
                      color: chordColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final innerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [chordWidget, lyricWidget],
    );

    // --- אזור הקליטה של הגרירה (Drag Target) ---
    final dropTarget = DragTarget<_ChordDragData>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isHovered = true);
        return true;
      },
      onMove: (details) => _updateHoverPosition(details.offset),
      onLeave: (_) => _clearHover(),
      onAcceptWithDetails: (details) {
        final finalCharIndex = _hoverCharIndex ?? 0;
        _clearHover();
        
        // כאן משודר העדכון אחורה שמעדכן את ה-ChordPro.
        // מכיוון שאנחנו ב-RTL, אינדקס 0 מייצג את הצד הימני ביותר (לפני האות הראשונה).
        widget.onDrop(details.data, widget.rawOffset + finalCharIndex);
      },
      builder: (context, candidateData, _) {
        return innerContent;
      },
    );

    if (widget.block.chord.isNotEmpty) {
      return Draggable<_ChordDragData>(
        data: _ChordDragData(
          lineIndex: widget.lineIndex,
          blockIndex: widget.blockIndex,
          chord: widget.block.chord,
        ),
        // העיצוב של האקורד שנגרר באוויר
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: chordColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Text(
              widget.block.chord,
              style: TextStyle(
                fontSize: widget.chordFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        childWhenDragging: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: widget.chordFontSize * 1.2), 
            lyricWidget, // מראה את המילים נשארות למטה עם הבלון שזז
          ],
        ),
        child: dropTarget,
      );
    }

    return dropTarget;
  }
}
class _ChordDragData {
  final int lineIndex;
  final int blockIndex;
  final String chord;
  const _ChordDragData({
    required this.lineIndex,
    required this.blockIndex,
    required this.chord,
  });
}
