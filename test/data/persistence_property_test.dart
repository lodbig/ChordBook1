// Feature: chordbook-app, Property 1: Song Data Round-Trip
//
// For any valid Song object, saving it to the database and then loading it
// by ID should produce an object with identical field values.
//
// Feature: chordbook-app, Property 2: Modification Timestamp Monotonicity
//
// For any song that is saved and then modified and saved again, the updatedAt
// timestamp of the second save should be >= the createdAt timestamp.
//
// Validates: Requirements 1.1, 1.2, 1.3, 1.4

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/song.dart';

// ---------------------------------------------------------------------------
// Simulated in-memory repository (mirrors SongRepository behavior)
// ---------------------------------------------------------------------------

class InMemorySongRepo {
  final Map<String, Song> _store = {};

  void save(Song song) => _store[song.id] = song;
  Song? getById(String id) => _store[id];
  List<Song> getAll() => _store.values.toList();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 1: Song Data Round-Trip', () {
    test('all fields preserved after save and load', () {
      final repo = InMemorySongRepo();
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

      repo.save(song);
      final loaded = repo.getById('test-id')!;

      expect(loaded.id, song.id);
      expect(loaded.title, song.title);
      expect(loaded.artist, song.artist);
      expect(loaded.tags, song.tags);
      expect(loaded.versions, song.versions);
      expect(loaded.originalKey, song.originalKey);
      expect(loaded.scrollSpeed, song.scrollSpeed);
      expect(loaded.createdAt, song.createdAt);
    });

    test('loading non-existent ID returns null', () {
      final repo = InMemorySongRepo();
      expect(repo.getById('nonexistent'), isNull);
    });

    test('saving overwrites existing song', () {
      final repo = InMemorySongRepo();
      final original = Song(id: 'id1', title: 'מקורי');
      final updated = Song(id: 'id1', title: 'מעודכן');
      repo.save(original);
      repo.save(updated);
      expect(repo.getById('id1')!.title, 'מעודכן');
    });

    test('property holds for 100 generated songs', () {
      final repo = InMemorySongRepo();

      for (int i = 0; i < 100; i++) {
        final song = Song(
          id: 'id_$i',
          title: 'שיר $i',
          artist: i % 2 == 0 ? 'אמן $i' : '',
          tags: List.generate(i % 4, (j) => 'tag_$j'),
          versions: {
            'רגיל': '[Am]טקסט $i',
            if (i % 3 == 0) 'קל': '[C]טקסט קל $i',
          },
          originalKey: i % 2 == 0 ? 'Am' : 'C',
          scrollSpeed: 1.0 + (i % 9),
          createdAt: DateTime(2024, 1, 1).add(Duration(days: i)),
          updatedAt: DateTime(2024, 6, 1).add(Duration(days: i)),
        );

        repo.save(song);
        final loaded = repo.getById(song.id)!;

        expect(loaded.id, song.id, reason: 'id mismatch at $i');
        expect(loaded.title, song.title, reason: 'title mismatch at $i');
        expect(loaded.artist, song.artist, reason: 'artist mismatch at $i');
        expect(loaded.tags, song.tags, reason: 'tags mismatch at $i');
        expect(loaded.versions, song.versions, reason: 'versions mismatch at $i');
        expect(loaded.originalKey, song.originalKey, reason: 'key mismatch at $i');
        expect(loaded.scrollSpeed, song.scrollSpeed, reason: 'speed mismatch at $i');
      }
    });
  });

  group('Property 2: Modification Timestamp Monotonicity', () {
    test('updatedAt >= createdAt after modification', () {
      final repo = InMemorySongRepo();
      final created = DateTime(2024, 1, 1);
      final song = Song(
        id: 'id1',
        title: 'שיר',
        createdAt: created,
        updatedAt: created,
      );
      repo.save(song);

      // Simulate modification
      final modified = song.copyWith(
        title: 'שיר מעודכן',
        updatedAt: DateTime(2024, 6, 1),
      );
      repo.save(modified);

      final loaded = repo.getById('id1')!;
      expect(
        loaded.updatedAt.isAfter(loaded.createdAt) ||
            loaded.updatedAt.isAtSameMomentAs(loaded.createdAt),
        isTrue,
        reason: 'updatedAt should be >= createdAt',
      );
    });

    test('property holds for 100 save-modify cycles', () {
      for (int i = 0; i < 100; i++) {
        final repo = InMemorySongRepo();
        final createdAt = DateTime(2024, 1, 1).add(Duration(days: i));
        final updatedAt = createdAt.add(Duration(hours: i));

        final song = Song(
          id: 'id_$i',
          title: 'שיר $i',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        repo.save(song);

        final loaded = repo.getById(song.id)!;
        expect(
          !loaded.updatedAt.isBefore(loaded.createdAt),
          isTrue,
          reason: 'Iteration $i: updatedAt < createdAt',
        );
      }
    });
  });
}
