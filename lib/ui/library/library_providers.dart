import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/custom_chord.dart';
import '../../data/models/song.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/custom_chord_repository.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/tag_repository.dart';

// ---------------------------------------------------------------------------
// Repositories (singleton providers)
// ---------------------------------------------------------------------------

final songRepositoryProvider = Provider((_) => SongRepository());
final tagRepositoryProvider = Provider((_) => TagRepository());

// ---------------------------------------------------------------------------
// Raw data
// ---------------------------------------------------------------------------

final allSongsProvider = FutureProvider<List<Song>>((ref) {
  return ref.watch(songRepositoryProvider).getAll();
});

final allTagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.watch(tagRepositoryProvider).getAll();
});

final allCustomChordsProvider = FutureProvider<List<CustomChord>>((ref) {
  return CustomChordRepository().getAll();
});

// ---------------------------------------------------------------------------
// Search & filter state
// ---------------------------------------------------------------------------

final searchQueryProvider = StateProvider<String>((_) => '');
final selectedTagFilterProvider = StateProvider<String?>((_) => null);

enum SortMode { title, artist }

final sortModeProvider = StateProvider<SortMode>((_) => SortMode.title);

// ---------------------------------------------------------------------------
// Derived: filtered + sorted songs
// ---------------------------------------------------------------------------

final filteredSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final songsAsync = ref.watch(allSongsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final tagFilter = ref.watch(selectedTagFilterProvider);
  final sort = ref.watch(sortModeProvider);

  return songsAsync.whenData((songs) {
    var result = songs.where((s) {
      // Text search
      final matchesQuery = query.isEmpty ||
          s.title.toLowerCase().contains(query) ||
          s.artist.toLowerCase().contains(query) ||
          s.tags.any((t) => t.toLowerCase().contains(query));

      // Tag filter
      final matchesTag =
          tagFilter == null || s.tags.contains(tagFilter);

      return matchesQuery && matchesTag;
    }).toList();

    // Sort
    if (sort == SortMode.title) {
      result.sort((a, b) => a.title.compareTo(b.title));
    } else {
      result.sort((a, b) {
        final cmp = a.artist.compareTo(b.artist);
        return cmp != 0 ? cmp : a.title.compareTo(b.title);
      });
    }

    return result;
  });
});

// ---------------------------------------------------------------------------
// Multi-select state
// ---------------------------------------------------------------------------

final selectedSongIdsProvider =
    StateProvider<Set<String>>((_) => const {});
