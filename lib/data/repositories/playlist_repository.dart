import '../database/database_manager.dart';
import '../models/playlist.dart';

class PlaylistRepository {
  static const _boxName = 'playlists';

  Future<List<Playlist>> getAll() async {
    final box = await DatabaseManager.openBox<Playlist>(_boxName);
    return box.values.toList();
  }

  Future<Playlist?> getById(String id) async {
    final box = await DatabaseManager.openBox<Playlist>(_boxName);
    try {
      return box.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Playlist playlist) async {
    final box = await DatabaseManager.openBox<Playlist>(_boxName);
    await box.put(playlist.id, playlist);
  }

  Future<void> delete(String id) async {
    final box = await DatabaseManager.openBox<Playlist>(_boxName);
    await box.delete(id);
  }
}
