import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/shortcut_definition.dart';
import '../settings/shortcut_providers.dart';

/// Wraps editor content with a [Focus] that intercepts keyboard shortcuts
/// even when focus is inside a [TextField].
class EditorKeyboardHandler extends ConsumerWidget {
  const EditorKeyboardHandler({
    super.key,
    required this.child,
    required this.onNudgeLeft,
    required this.onNudgeRight,
    required this.onChordAtIndex,
    required this.onCustomChordById,
  });

  final Widget child;
  final VoidCallback onNudgeLeft;
  final VoidCallback onNudgeRight;

  /// Called with 0-based index when a diatonic chord shortcut is triggered.
  final void Function(int index) onChordAtIndex;

  /// Called with the chord's original id when a custom chord shortcut is triggered.
  final void Function(String chordId) onCustomChordById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(shortcutsProvider);
    final customShortcuts = ref.watch(dynamicCustomChordShortcutsProvider);

    // Combine fixed + dynamic shortcuts for matching
    final allShortcuts = [
      ...shortcuts.values,
      // Only include custom shortcuts that have a real key assigned
      ...customShortcuts.where((s) => s.key != kNoKey),
    ];

    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final hw = HardwareKeyboard.instance;
        final isCtrl = hw.isControlPressed;
        final isAlt = hw.isAltPressed;
        final isShift = hw.isShiftPressed;

        for (final s in allShortcuts) {
          if (event.logicalKey == s.key &&
              isCtrl == s.ctrl &&
              isAlt == s.alt &&
              isShift == s.shift) {
            _dispatch(s.id);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  void _dispatch(String id) {
    if (id == 'nudge_left') {
      onNudgeLeft();
    } else if (id == 'nudge_right') {
      onNudgeRight();
    } else if (id.startsWith('custom_chord_')) {
      final chordId = id.substring('custom_chord_'.length);
      onCustomChordById(chordId);
    } else if (id.startsWith('chord_')) {
      final indexStr = id.substring('chord_'.length);
      final index = int.tryParse(indexStr);
      if (index != null) {
        // chord_1 → index 0
        onChordAtIndex(index - 1);
      }
    }
  }
}
