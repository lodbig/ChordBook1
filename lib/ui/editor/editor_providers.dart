import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import '../../data/repositories/song_repository.dart';
import '../library/library_providers.dart';

// ---------------------------------------------------------------------------
// Current song being edited
// ---------------------------------------------------------------------------

final currentSongProvider =
    StateNotifierProvider.family<CurrentSongNotifier, Song?, String>(
  (ref, id) => CurrentSongNotifier(ref.read(songRepositoryProvider), ref, id),
);

class CurrentSongNotifier extends StateNotifier<Song?> {
  CurrentSongNotifier(this._repo, this._ref, this._id) : super(null) {
    _load();
  }

  final SongRepository _repo;
  final Ref _ref;
  final String _id;

  Future<void> _load() async {
    state = await _repo.getById(_id);
  }

  Future<void> update(Song song) async {
    final updated = song.copyWith(updatedAt: DateTime.now());
    await _repo.save(updated);
    state = updated;
    // Invalidate so library + performance screens see the latest data
    _ref.invalidate(allSongsProvider);
  }

  Future<void> updateField({
    String? title,
    String? artist,
    String? originalKey,
    double? scrollSpeed,
    List<String>? tags,
    Map<String, String>? versions,
    Map<String, String>? versionKeys,
  }) async {
    if (state == null) return;
    await update(state!.copyWith(
      title: title,
      artist: artist,
      originalKey: originalKey,
      scrollSpeed: scrollSpeed,
      tags: tags,
      versions: versions,
      versionKeys: versionKeys,
    ));
  }

  /// Returns the current song state (for reading from outside the notifier).
  Song? getCurrentSong() => state;
}

// ---------------------------------------------------------------------------
// Active version tab
// ---------------------------------------------------------------------------

final activeVersionProvider =
    StateProvider.family<String?, String>((ref, songId) => null);
