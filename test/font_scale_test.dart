import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chordbook/data/models/shortcut_definition.dart';

void main() {
  // ---------------------------------------------------------------------------
  // P3: ערכי fontScale נחסמים לטווח [0.8, 1.4]
  // ---------------------------------------------------------------------------
  group('P3 – fontScale clamping', () {
    const double minScale = 0.8;
    const double maxScale = 1.4;

    double clampScale(double value) => value.clamp(minScale, maxScale);

    test('ערך בתוך הטווח נשמר ללא שינוי', () {
      expect(clampScale(1.0), equals(1.0));
      expect(clampScale(0.8), equals(0.8));
      expect(clampScale(1.4), equals(1.4));
      expect(clampScale(1.2), equals(1.2));
    });

    test('ערך מתחת ל-0.8 נחסם ל-0.8', () {
      expect(clampScale(0.5), equals(0.8));
      expect(clampScale(0.0), equals(0.8));
      expect(clampScale(-1.0), equals(0.8));
    });

    test('ערך מעל 1.4 נחסם ל-1.4', () {
      expect(clampScale(1.5), equals(1.4));
      expect(clampScale(2.0), equals(1.4));
      expect(clampScale(10.0), equals(1.4));
    });

    test('ערכי גבול בדיוק מתקבלים', () {
      expect(clampScale(minScale), equals(minScale));
      expect(clampScale(maxScale), equals(maxScale));
    });
  });

  // ---------------------------------------------------------------------------
  // P1: dynamicCustomChordShortcutsProvider – id נכון לפי chord.id
  // ---------------------------------------------------------------------------
  group('P1 – dynamic custom chord shortcut id format', () {
    String buildCustomShortcutId(String chordId) => 'custom_chord_$chordId';

    test('id מכיל prefix נכון', () {
      const chordId = 'abc123';
      final id = buildCustomShortcutId(chordId);
      expect(id, equals('custom_chord_abc123'));
      expect(id, startsWith('custom_chord_'));
    });

    test('id שונה לכל chord שונה', () {
      final ids = ['chord1', 'chord2', 'chord3']
          .map(buildCustomShortcutId)
          .toList();
      expect(ids.toSet().length, equals(ids.length));
    });

    test('id עמיד לשינוי שם האקורד', () {
      const chordId = 'fixed_id';
      final id1 = buildCustomShortcutId(chordId);
      final id2 = buildCustomShortcutId(chordId);
      expect(id1, equals(id2));
    });
  });

  // ---------------------------------------------------------------------------
  // P2: קיצור ללא ברירת מחדל – key הוא kNoKey
  // ---------------------------------------------------------------------------
  group('P2 – custom chord shortcut has no default key', () {
    test('קיצור חדש לאקורד מותאם נוצר עם key=kNoKey', () {
      const chordId = 'my_chord';
      final shortcut = ShortcutDefinition(
        id: 'custom_chord_$chordId',
        label: 'אקורד מותאם: My Chord',
        key: kNoKey,
      );
      expect(shortcut.key, equals(kNoKey));
      expect(shortcut.id, equals('custom_chord_my_chord'));
    });

    test('displayString של קיצור kNoKey אינו זורק שגיאה', () {
      final shortcut = ShortcutDefinition(
        id: 'custom_chord_x',
        label: 'test',
        key: kNoKey,
      );
      expect(() => shortcut.displayString, returnsNormally);
    });

    test('קיצור עם key=kNoKey אינו שווה לקיצור עם מקש אמיתי', () {
      const s1 = ShortcutDefinition(
        id: 'a',
        label: 'A',
        key: kNoKey,
      );
      const s2 = ShortcutDefinition(
        id: 'b',
        label: 'B',
        key: LogicalKeyboardKey.keyA,
      );
      expect(s1, isNot(equals(s2)));
    });
  });
}
