import 'dart:convert';

import '../database/database_manager.dart';
import '../models/default_shortcuts.dart';
import '../models/shortcut_definition.dart';

class ShortcutRepository {
  static const _boxName = 'shortcuts';

  Future<Map<String, ShortcutDefinition>> getAll() async {
    final box = await DatabaseManager.openBox<String>(_boxName);
    final result = <String, ShortcutDefinition>{};
    for (final key in box.keys) {
      try {
        final json = jsonDecode(box.get(key as String)!) as Map<String, dynamic>;
        final s = ShortcutDefinition.fromJson(json);
        result[s.id] = s;
      } catch (_) {}
    }
    return result;
  }

  Future<void> save(ShortcutDefinition shortcut) async {
    final box = await DatabaseManager.openBox<String>(_boxName);
    await box.put(shortcut.id, jsonEncode(shortcut.toJson()));
  }

  Future<void> reset(String id) async {
    final box = await DatabaseManager.openBox<String>(_boxName);
    await box.delete(id);
  }

  Future<void> resetAll() async {
    final box = await DatabaseManager.openBox<String>(_boxName);
    await box.clear();
  }

  /// Returns the effective shortcut: saved override or default.
  Future<ShortcutDefinition?> getById(String id) async {
    final all = await getAll();
    return all[id] ?? DefaultShortcuts.getById(id);
  }
}
