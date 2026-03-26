import 'package:flutter/services.dart';

import 'shortcut_definition.dart';

class DefaultShortcuts {
  DefaultShortcuts._();

  static const nudgeLeft = ShortcutDefinition(
    id: 'nudge_left',
    label: 'הזז אקורד ימינה',
    key: LogicalKeyboardKey.arrowLeft,
    ctrl: true,
  );

  static const nudgeRight = ShortcutDefinition(
    id: 'nudge_right',
    label: 'הזז אקורד שמאלה',
    key: LogicalKeyboardKey.arrowRight,
    ctrl: true,
  );

  static final List<ShortcutDefinition> chordShortcuts = [
    ShortcutDefinition(id: 'chord_1', label: 'אקורד 1', key: LogicalKeyboardKey.digit1, ctrl: true),
    ShortcutDefinition(id: 'chord_2', label: 'אקורד 2', key: LogicalKeyboardKey.digit2, ctrl: true),
    ShortcutDefinition(id: 'chord_3', label: 'אקורד 3', key: LogicalKeyboardKey.digit3, ctrl: true),
    ShortcutDefinition(id: 'chord_4', label: 'אקורד 4', key: LogicalKeyboardKey.digit4, ctrl: true),
    ShortcutDefinition(id: 'chord_5', label: 'אקורד 5', key: LogicalKeyboardKey.digit5, ctrl: true),
    ShortcutDefinition(id: 'chord_6', label: 'אקורד 6', key: LogicalKeyboardKey.digit6, ctrl: true),
    ShortcutDefinition(id: 'chord_7', label: 'אקורד 7', key: LogicalKeyboardKey.digit7, ctrl: true),
  ];

  static List<ShortcutDefinition> get all => [
        nudgeLeft,
        nudgeRight,
        ...chordShortcuts,
      ];

  static ShortcutDefinition? getById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
