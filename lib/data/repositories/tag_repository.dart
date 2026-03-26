import '../database/database_manager.dart';
import '../models/tag.dart';
import '../models/song.dart';

class TagRepository {
  static const _boxName = 'tags';

  Future<List<Tag>> getAll() async {
    final box = await DatabaseManager.openBox<Tag>(_boxName);
    return box.values.toList();
  }

  Future<Tag?> getById(String id) async {
    final box = await DatabaseManager.openBox<Tag>(_boxName);
    try {
      return box.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Tag tag) async {
    final box = await DatabaseManager.openBox<Tag>(_boxName);
    await box.put(tag.id, tag);
  }

  Future<void> delete(String id) async {
    final box = await DatabaseManager.openBox<Tag>(_boxName);
    await box.delete(id);
  }

  /// Remove a tag from all songs that reference it.
  Future<void> removeFromAllSongs(String tagId) async {
    final songBox = await DatabaseManager.openBox<Song>('songs');
    for (final song in songBox.values) {
      if (song.tags.contains(tagId)) {
        song.tags = List<String>.from(song.tags)..remove(tagId);
        await songBox.put(song.id, song);
      }
    }
  }
}
