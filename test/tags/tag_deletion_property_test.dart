// Feature: chordbook-app, Property 7: Tag Deletion Removes from All Songs
//
// For any tag and any set of songs that include that tag, after the tag is
// deleted, no song in the library should contain that tag ID in its tags list.
//
// Validates: Requirements 6.4

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/song.dart';

// ---------------------------------------------------------------------------
// Inline cascade logic (mirrors TagRepository.removeFromAllSongs)
// ---------------------------------------------------------------------------

List<Song> removeTagFromAllSongs(List<Song> songs, String tagId) {
  return songs.map((s) {
    if (!s.tags.contains(tagId)) return s;
    return s.copyWith(tags: List<String>.from(s.tags)..remove(tagId));
  }).toList();
}

Song _song(String id, List<String> tags) =>
    Song(id: id, title: 'שיר $id', tags: tags);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 7: Tag Deletion Removes from All Songs – unit tests', () {
    test('tag is removed from all songs that have it', () {
      final songs = [
        _song('1', ['tag_a', 'tag_b']),
        _song('2', ['tag_b', 'tag_c']),
        _song('3', ['tag_c']),
      ];
      final result = removeTagFromAllSongs(songs, 'tag_b');
      for (final s in result) {
        expect(s.tags, isNot(contains('tag_b')));
      }
    });

    test('other tags are preserved', () {
      final songs = [_song('1', ['tag_a', 'tag_b'])];
      final result = removeTagFromAllSongs(songs, 'tag_b');
      expect(result.first.tags, contains('tag_a'));
    });

    test('songs without the tag are unchanged', () {
      final songs = [_song('1', ['tag_c'])];
      final result = removeTagFromAllSongs(songs, 'tag_b');
      expect(result.first.tags, ['tag_c']);
    });

    test('deleting non-existent tag changes nothing', () {
      final songs = [_song('1', ['tag_a'])];
      final result = removeTagFromAllSongs(songs, 'tag_x');
      expect(result.first.tags, ['tag_a']);
    });

    test('empty library returns empty', () {
      final result = removeTagFromAllSongs([], 'tag_a');
      expect(result, isEmpty);
    });
  });

  group('Property 7: Tag Deletion – property test (100 inputs)', () {
    test('no song contains the deleted tag after removal', () {
      final tagPool = List.generate(10, (i) => 'tag_$i');

      for (int i = 0; i < 100; i++) {
        final tagToDelete = tagPool[i % tagPool.length];
        final songCount = (i % 15) + 1;

        final songs = List.generate(songCount, (j) {
          // Each song gets a random subset of tags
          final tags = tagPool.where((t) => (i + j + tagPool.indexOf(t)) % 3 == 0).toList();
          return _song('song_${i}_$j', tags);
        });

        final result = removeTagFromAllSongs(songs, tagToDelete);

        for (final song in result) {
          expect(
            song.tags,
            isNot(contains(tagToDelete)),
            reason:
                'Iteration $i: song "${song.id}" still contains "$tagToDelete"',
          );
        }

        // Verify other tags are preserved
        for (int j = 0; j < songs.length; j++) {
          final original = songs[j];
          final updated = result[j];
          for (final t in original.tags) {
            if (t != tagToDelete) {
              expect(
                updated.tags,
                contains(t),
                reason:
                    'Iteration $i: song "${original.id}" lost tag "$t" which should be preserved',
              );
            }
          }
        }
      }
    });
  });
}
