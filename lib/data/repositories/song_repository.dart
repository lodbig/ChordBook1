import '../database/database_manager.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class SongRepository {
  static const _boxName = 'songs';

  Future<List<Song>> getAll() async {
    final box = await DatabaseManager.openBox<Song>(_boxName);
    return box.values.toList();
  }

  Future<Song?> getById(String id) async {
    final box = await DatabaseManager.openBox<Song>(_boxName);
    try {
      return box.values.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Song song) async {
    final box = await DatabaseManager.openBox<Song>(_boxName);
    await box.put(song.id, song);
  }

  Future<void> delete(String id) async {
    final box = await DatabaseManager.openBox<Song>(_boxName);
    await box.delete(id);
    // הסר את השיר מכל רשימות הניגון
    final playlistBox = await DatabaseManager.openBox<Playlist>('playlists');
    for (final playlist in playlistBox.values) {
      if (playlist.songIds.contains(id)) {
        final updated = playlist.copyWith(
          songIds: playlist.songIds.where((sid) => sid != id).toList(),
          songVersions: Map<String, String>.from(playlist.songVersions)
            ..remove(id),
        );
        await playlistBox.put(updated.id, updated);
      }
    }
  }

  /// Search songs by title, artist, or tags (case-insensitive).
  Future<List<Song>> search(String query) async {
    if (query.isEmpty) return getAll();
    final lower = query.toLowerCase();
    final box = await DatabaseManager.openBox<Song>(_boxName);
    return box.values.where((song) {
      if (song.title.toLowerCase().contains(lower)) return true;
      if (song.artist.toLowerCase().contains(lower)) return true;
      if (song.tags.any((t) => t.toLowerCase().contains(lower))) return true;
      return false;
    }).toList();
  }
}
