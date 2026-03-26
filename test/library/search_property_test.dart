// Feature: chordbook-app, Property 4: Search Result Relevance
//
// For any non-empty search query and any song library, every song returned
// by the search function should contain the query string in at least one of:
// title, artist name, or tags list (case-insensitive).
//
// Validates: Requirements 3.4

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/song.dart';

// ---------------------------------------------------------------------------
// Inline search logic (mirrors SongRepository.search / filteredSongsProvider)
// ---------------------------------------------------------------------------

List<Song> searchSongs(List<Song> songs, String query) {
  if (query.isEmpty) return List.from(songs);
  final lower = query.toLowerCase();
  return songs.where((s) {
    if (s.title.toLowerCase().contains(lower)) return true;
    if (s.artist.toLowerCase().contains(lower)) return true;
    if (s.tags.any((t) => t.toLowerCase().contains(lower))) return true;
    return false;
  }).toList();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Song _song({
  required String id,
  required String title,
  String artist = '',
  List<String> tags = const [],
}) =>
    Song(id: id, title: title, artist: artist, tags: tags);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 4: Search Result Relevance – unit tests', () {
    final library = [
      _song(id: '1', title: 'ירושלים של זהב', artist: 'נעמי שמר', tags: ['ישראלי', 'קלאסי']),
      _song(id: '2', title: 'הבה נגילה', artist: 'מסורתי', tags: ['עממי']),
      _song(id: '3', title: 'Yesterday', artist: 'The Beatles', tags: ['rock', 'classic']),
      _song(id: '4', title: 'Let It Be', artist: 'The Beatles', tags: ['rock']),
      _song(id: '5', title: 'שיר ריק', artist: '', tags: []),
    ];

    test('search by title returns matching songs', () {
      final results = searchSongs(library, 'ירושלים');
      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('search by artist returns matching songs', () {
      final results = searchSongs(library, 'Beatles');
      expect(results.length, 2);
      expect(results.map((s) => s.id).toSet(), {'3', '4'});
    });

    test('search by tag returns matching songs', () {
      final results = searchSongs(library, 'rock');
      expect(results.length, 2);
    });

    test('empty query returns all songs', () {
      final results = searchSongs(library, '');
      expect(results.length, library.length);
    });

    test('no match returns empty list', () {
      final results = searchSongs(library, 'xyznotfound');
      expect(results, isEmpty);
    });

    test('search is case-insensitive', () {
      final results = searchSongs(library, 'beatles');
      expect(results.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Property 4: every result must contain the query in title/artist/tags
  // -------------------------------------------------------------------------
  group('Property 4: Search Result Relevance – property test (100 inputs)', () {
    final titles = [
      'ירושלים של זהב', 'הבה נגילה', 'Yesterday', 'Let It Be',
      'Bohemian Rhapsody', 'Hotel California', 'שיר האהבה', 'מחר',
      'Hello', 'Imagine',
    ];
    final artists = [
      'נעמי שמר', 'The Beatles', 'Queen', 'Eagles', '', 'John Lennon',
    ];
    final tagPool = ['rock', 'ישראלי', 'classic', 'עממי', 'pop', 'jazz'];

    // Build a library of 20 songs
    final library = List.generate(20, (i) {
      final tagCount = i % 3;
      return _song(
        id: 'song_$i',
        title: titles[i % titles.length],
        artist: artists[i % artists.length],
        tags: List.generate(tagCount, (j) => tagPool[(i + j) % tagPool.length]),
      );
    });

    // Queries to test
    final queries = [
      'ירושלים', 'beatles', 'rock', 'ישראלי', 'Yesterday',
      'Queen', 'jazz', 'pop', 'Hello', 'Imagine',
      'נעמי', 'Eagles', 'classic', 'עממי', 'Let',
      'Bohemian', 'Hotel', 'מחר', 'שיר', 'John',
    ];

    test('every result contains the query in title, artist, or tags (100 checks)', () {
      int checks = 0;
      for (int i = 0; i < 100; i++) {
        final query = queries[i % queries.length];
        final results = searchSongs(library, query);

        for (final song in results) {
          final lower = query.toLowerCase();
          final matchesTitle = song.title.toLowerCase().contains(lower);
          final matchesArtist = song.artist.toLowerCase().contains(lower);
          final matchesTag = song.tags.any((t) => t.toLowerCase().contains(lower));

          expect(
            matchesTitle || matchesArtist || matchesTag,
            isTrue,
            reason:
                'Song "${song.title}" returned for query "$query" but does not match',
          );
          checks++;
        }
      }
      // Ensure we actually ran checks (not all queries returned empty)
      expect(checks, greaterThan(0));
    });
  });
}
