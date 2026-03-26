import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/default_shortcuts.dart';
import '../../data/models/shortcut_definition.dart';
import '../../data/repositories/shortcut_repository.dart';
import '../library/library_providers.dart';

final shortcutRepositoryProvider = Provider((_) => ShortcutRepository());

final shortcutsProvider =
    StateNotifierProvider<ShortcutsNotifier, Map<String, ShortcutDefinition>>(
  (ref) => ShortcutsNotifier(ref.read(shortcutRepositoryProvider)),
);

class ShortcutsNotifier extends StateNotifier<Map<String, ShortcutDefinition>> {
  ShortcutsNotifier(this._repo) : super({}) {
    _load();
  }

  final ShortcutRepository _repo;

  Future<void> _load() async {
    final saved = await _repo.getAll();
    // Merge defaults with saved overrides
    final merged = <String, ShortcutDefinition>{};
    for (final def in DefaultShortcuts.all) {
      merged[def.id] = saved[def.id] ?? def;
    }
    // Also load any saved custom_chord_* shortcuts
    for (final entry in saved.entries) {
      if (entry.key.startsWith('custom_chord_')) {
        merged[entry.key] = entry.value;
      }
    }
    state = merged;
  }

  /// Returns the effective shortcut for [id], falling back to default.
  ShortcutDefinition? get(String id) => state[id];

  /// Updates a shortcut. Returns conflicting shortcut id if duplicate, null otherwise.
  Future<String?> update(ShortcutDefinition shortcut) async {
    // Check for conflicts (same key combo, different id)
    final conflict = state.values.firstWhere(
      (s) => s.id != shortcut.id && s == shortcut,
      orElse: () => shortcut, // no conflict found
    );
    if (conflict.id != shortcut.id) {
      return conflict.id; // caller can show warning
    }

    await _repo.save(shortcut);
    state = {...state, shortcut.id: shortcut};
    return null;
  }

  /// Resets a shortcut to its default value.
  Future<void> reset(String id) async {
    await _repo.reset(id);
    final def = DefaultShortcuts.getById(id);
    if (def != null) {
      state = {...state, id: def};
    }
  }
}

/// Provider דינמי שמייצר קיצורים לפי האקורדים המותאמים הקיימים.
/// id הקיצור: 'custom_chord_{chord.id}' – עמיד לשינויי סדר ושם.
/// אין ברירת מחדל – המשתמש מגדיר בעצמו.
final dynamicCustomChordShortcutsProvider =
    Provider<List<ShortcutDefinition>>((ref) {
  final customChords =
      ref.watch(allCustomChordsProvider).valueOrNull ?? [];
  final saved = ref.watch(shortcutsProvider);

  return customChords.map((chord) {
    final id = 'custom_chord_${chord.id}';
    return saved[id] ??
        ShortcutDefinition(
          id: id,
          label: 'אקורד מותאם: ${chord.name}',
          key: kNoKey,
        );
  }).toList();
});
