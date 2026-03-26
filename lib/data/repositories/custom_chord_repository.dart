import '../database/database_manager.dart';
import '../models/custom_chord.dart';

class CustomChordRepository {
  static const _boxName = 'custom_chords';

  Future<List<CustomChord>> getAll() async {
    final box = await DatabaseManager.openBox<CustomChord>(_boxName);
    final chords = box.values.toList();
    chords.sort((a, b) => a.order.compareTo(b.order));
    return chords;
  }

  Future<void> save(CustomChord chord) async {
    final box = await DatabaseManager.openBox<CustomChord>(_boxName);
    await box.put(chord.id, chord);
  }

  Future<void> delete(String id) async {
    final box = await DatabaseManager.openBox<CustomChord>(_boxName);
    await box.delete(id);
  }

  /// Reorder chords by updating their order field to match the given list order.
  Future<void> reorder(List<String> orderedIds) async {
    final box = await DatabaseManager.openBox<CustomChord>(_boxName);
    for (int i = 0; i < orderedIds.length; i++) {
      final chord = box.get(orderedIds[i]);
      if (chord != null) {
        final updated = chord.copyWith(order: i);
        await box.put(updated.id, updated);
      }
    }
  }
}
