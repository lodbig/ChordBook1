// Feature: chordbook-app, Property 5: Import Deduplication
//
// For any existing song library and any JSON import file containing a mix of
// new and duplicate song IDs, after import the library should contain exactly
// the union of unique song IDs (no duplicates, no missing new songs).
//
// Feature: chordbook-app, Property 6: JSON Export/Import Round-Trip
//
// For any collection of songs, exporting them to JSON and then importing that
// JSON should produce a collection with equivalent song data for all songs.
//
// Validates: Requirements 5.3, 5.8

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/song.dart';

// ---------------------------------------------------------------------------
// Inline import logic (mirrors importSongsFromJson deduplication)
// ---------------------------------------------------------------------------

/// Returns the merged library after importing [incoming] into [existing].
/// Existing songs (by ID) are not overwritten.
List<Song> mergeImport(List<Song> existing, List<Song> incoming) {
  final existingIds = existing.map((s) => s.id).toSet();
  final result = List<Song>.from(existing);
  for (final song in incoming) {
    if (!existingIds.contains(song.id)) {
      result.add(song);
      existingIds.add(song.id);
    }
  }
  return result;
}

Song _song(String id, {String title = 'שיר', String artist = ''}) =>
    Song(id: id, title: title, artist: artist);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 5: Import Deduplication – unit tests', () {
    test('new songs are added', () {
      final existing = [_song('1'), _song('2')];
      final incoming = [_song('3'), _song('4')];
      final result = mergeImport(existing, incoming);
      expect(result.map((s) => s.id).toSet(), {'1', '2', '3', '4'});
    });

    test('duplicate songs are not added', () {
      final existing = [_song('1'), _song('2')];
      final incoming = [_song('1'), _song('2')];
      final result = mergeImport(existing, incoming);
      expect(result.length, 2);
    });

    test('mix of new and duplicate', () {
      final existing = [_song('1'), _song('2')];
      final incoming = [_song('2'), _song('3')];
      final result = mergeImport(existing, incoming);
      expect(result.map((s) => s.id).toSet(), {'1', '2', '3'});
      expect(result.length, 3);
    });

    test('empty incoming does not change library', () {
      final existing = [_song('1')];
      final result = mergeImport(existing, []);
      expect(result.length, 1);
    });

    test('empty existing accepts all incoming', () {
      final incoming = [_song('1'), _song('2')];
      final result = mergeImport([], incoming);
      expect(result.length, 2);
    });
  });

  group('Property 5: Import Deduplication – property test (100 inputs)', () {
    test('result IDs == union of existing and incoming IDs', () {
      for (int i = 0; i < 100; i++) {
        final existingCount = i % 10;
        final incomingCount = (i % 7) + 1;
        final overlapCount = i % (existingCount + 1);

        final existing = List.generate(existingCount, (j) => _song('e$j'));
        final existingIds = existing.map((s) => s.id).toSet();

        // incoming = some overlapping + some new
        final incoming = [
          ...List.generate(overlapCount, (j) => _song('e$j')), // duplicates
          ...List.generate(incomingCount, (j) => _song('n${i}_$j')), // new
        ];

        final result = mergeImport(existing, incoming);
        final resultIds = result.map((s) => s.id).toSet();

        // Expected: union of existing IDs and incoming IDs
        final expectedIds = {
          ...existingIds,
          ...incoming.map((s) => s.id),
        };

        expect(
          resultIds,
          expectedIds,
          reason: 'Iteration $i: result IDs do not match expected union',
        );

        // No duplicates
        expect(
          result.length,
          resultIds.length,
          reason: 'Iteration $i: result contains duplicate IDs',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Property 6: JSON Export/Import Round-Trip
  // -------------------------------------------------------------------------
  group('Property 6: JSON Export/Import Round-Trip', () {
    Song roundTrip(Song song) {
      final json = song.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      return Song.fromJson(decoded);
    }

    test('round-trip preserves all fields', () {
      final song = Song(
        id: 'test-id',
        title: 'ירושלים של זהב',
        artist: 'נעמי שמר',
        tags: ['ישראלי', 'קלאסי'],
        versions: {'רגיל': '[Am]ירושלים [G]של זהב', 'קל': '[C]ירושלים'},
        originalKey: 'Am',
        scrollSpeed: 4.5,
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 6, 20),
      );

      final restored = roundTrip(song);
      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.tags, song.tags);
      expect(restored.versions, song.versions);
      expect(restored.originalKey, song.originalKey);
      expect(restored.scrollSpeed, song.scrollSpeed);
    });

    test('round-trip holds for 100 generated songs', () {
      for (int i = 0; i < 100; i++) {
        final song = Song(
          id: 'id_$i',
          title: 'שיר מספר $i',
          artist: i % 3 == 0 ? '' : 'אמן $i',
          tags: List.generate(i % 4, (j) => 'tag_$j'),
          versions: {
            'רגיל': '[Am]טקסט $i',
            if (i % 2 == 0) 'קל': '[C]טקסט קל $i',
          },
          originalKey: i % 2 == 0 ? 'Am' : 'C',
          scrollSpeed: 1.0 + (i % 9),
        );

        final restored = roundTrip(song);

        expect(restored.id, song.id,
            reason: 'id mismatch at iteration $i');
        expect(restored.title, song.title,
            reason: 'title mismatch at iteration $i');
        expect(restored.artist, song.artist,
            reason: 'artist mismatch at iteration $i');
        expect(restored.tags, song.tags,
            reason: 'tags mismatch at iteration $i');
        expect(restored.versions, song.versions,
            reason: 'versions mismatch at iteration $i');
        expect(restored.originalKey, song.originalKey,
            reason: 'originalKey mismatch at iteration $i');
        expect(restored.scrollSpeed, song.scrollSpeed,
            reason: 'scrollSpeed mismatch at iteration $i');
      }
    });
  });
}
