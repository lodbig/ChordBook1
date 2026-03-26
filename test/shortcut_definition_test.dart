import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordbook/data/models/shortcut_definition.dart';
import 'package:chordbook/data/models/default_shortcuts.dart';

void main() {
  // ---------------------------------------------------------------------------
  // P1: displayString always contains the key label
  // ---------------------------------------------------------------------------
  group('P1 – displayString contains key label', () {
    test('Ctrl+Left contains "Arrow Left"', () {
      const s = ShortcutDefinition(
        id: 'test',
        label: 'test',
        key: LogicalKeyboardKey.arrowLeft,
        ctrl: true,
      );
      expect(s.displayString, contains('Arrow Left'));
      expect(s.displayString, contains('Ctrl'));
    });

    test('Ctrl+1 contains "1"', () {
      const s = ShortcutDefinition(
        id: 'test',
        label: 'test',
        key: LogicalKeyboardKey.digit1,
        ctrl: true,
      );
      expect(s.displayString, contains('1'));
      expect(s.displayString, contains('Ctrl'));
    });

    test('displayString without modifiers is just the key label', () {
      const s = ShortcutDefinition(
        id: 'test',
        label: 'test',
        key: LogicalKeyboardKey.keyA,
      );
      expect(s.displayString, equals(LogicalKeyboardKey.keyA.keyLabel));
    });

    test('all default shortcuts have non-empty displayString', () {
      for (final s in DefaultShortcuts.all) {
        expect(s.displayString, isNotEmpty,
            reason: '${s.id} has empty displayString');
        expect(s.displayString, contains(s.key.keyLabel),
            reason: '${s.id} displayString missing key label');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // P3: JSON round-trip preserves all fields
  // ---------------------------------------------------------------------------
  group('P3 – JSON round-trip', () {
    test('toJson/fromJson preserves all fields', () {
      const original = ShortcutDefinition(
        id: 'nudge_left',
        label: 'הזז אקורד ימינה',
        key: LogicalKeyboardKey.arrowLeft,
        ctrl: true,
        alt: false,
        shift: false,
      );
      final json = original.toJson();
      final restored = ShortcutDefinition.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.label, equals(original.label));
      expect(restored.key, equals(original.key));
      expect(restored.ctrl, equals(original.ctrl));
      expect(restored.alt, equals(original.alt));
      expect(restored.shift, equals(original.shift));
    });

    test('round-trip for all default shortcuts', () {
      for (final s in DefaultShortcuts.all) {
        final restored = ShortcutDefinition.fromJson(s.toJson());
        expect(restored.id, equals(s.id));
        expect(restored.key, equals(s.key));
        expect(restored.ctrl, equals(s.ctrl));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // P4: equality detects duplicate key combos
  // ---------------------------------------------------------------------------
  group('P4 – duplicate detection via equality', () {
    test('same key+modifiers are equal regardless of id/label', () {
      const s1 = ShortcutDefinition(
        id: 'action_a',
        label: 'A',
        key: LogicalKeyboardKey.digit1,
        ctrl: true,
      );
      const s2 = ShortcutDefinition(
        id: 'action_b',
        label: 'B',
        key: LogicalKeyboardKey.digit1,
        ctrl: true,
      );
      expect(s1, equals(s2));
    });

    test('different modifiers are not equal', () {
      const s1 = ShortcutDefinition(
        id: 'a',
        label: 'A',
        key: LogicalKeyboardKey.digit1,
        ctrl: true,
      );
      const s2 = ShortcutDefinition(
        id: 'b',
        label: 'B',
        key: LogicalKeyboardKey.digit1,
        alt: true,
      );
      expect(s1, isNot(equals(s2)));
    });
  });

  // ---------------------------------------------------------------------------
  // P2: insert chord preserves existing text
  // ---------------------------------------------------------------------------
  group('P2 – chord insertion preserves text', () {
    String insertChord(String text, int pos, String chord) {
      final insertPos =
          (pos >= 0 && pos <= text.length) ? pos : text.length;
      final inserted = '[$chord]';
      return text.substring(0, insertPos) +
          inserted +
          text.substring(insertPos);
    }

    test('inserted chord is contained in result', () {
      const text = 'שלום עולם';
      const chord = 'Am';
      final result = insertChord(text, 5, chord);
      expect(result, contains('[Am]'));
      expect(result, contains('שלום'));
      expect(result, contains('עולם'));
    });

    test('original text is preserved at any position', () {
      const text = 'abc';
      for (int pos = 0; pos <= text.length; pos++) {
        final result = insertChord(text, pos, 'C');
        // Original chars still present
        expect(result.replaceAll('[C]', ''), equals(text));
      }
    });

    test('insert at end appends chord', () {
      const text = 'hello';
      final result = insertChord(text, text.length, 'G');
      expect(result, equals('hello[G]'));
    });

    test('insert at start prepends chord', () {
      const text = 'hello';
      final result = insertChord(text, 0, 'G');
      expect(result, equals('[G]hello'));
    });
  });
}
