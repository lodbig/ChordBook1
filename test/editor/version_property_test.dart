// Feature: chordbook-app, Property 8: Minimum One Version Per Song
//
// For any song with N versions (N ≥ 1), attempting to delete all versions
// should leave exactly one version remaining (the last version cannot be deleted).
//
// Validates: Requirements 9.7

import 'package:flutter_test/flutter_test.dart';
import 'package:chordbook/data/models/song.dart';

// ---------------------------------------------------------------------------
// Inline version deletion logic (mirrors _VersionTabBar._deleteVersion)
// ---------------------------------------------------------------------------

/// Attempts to delete [versionName] from [song].
/// Returns the updated song, or the original if deletion is not allowed
/// (i.e., it's the last version).
Song tryDeleteVersion(Song song, String versionName) {
  if (song.versions.length <= 1) return song; // cannot delete last version
  final newVersions = Map<String, String>.from(song.versions)
    ..remove(versionName);
  return song.copyWith(versions: newVersions);
}

Song _song(Map<String, String> versions) => Song(
      id: 'test',
      title: 'שיר',
      versions: versions,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 8: Minimum One Version – unit tests', () {
    test('cannot delete the only version', () {
      final song = _song({'רגיל': 'טקסט'});
      final result = tryDeleteVersion(song, 'רגיל');
      expect(result.versions.length, 1);
      expect(result.versions.containsKey('רגיל'), isTrue);
    });

    test('can delete one of two versions', () {
      final song = _song({'רגיל': 'טקסט', 'קל': 'טקסט קל'});
      final result = tryDeleteVersion(song, 'קל');
      expect(result.versions.length, 1);
      expect(result.versions.containsKey('רגיל'), isTrue);
    });

    test('deleting all versions one by one leaves exactly one', () {
      var song = _song({'א': 'a', 'ב': 'b', 'ג': 'c'});
      song = tryDeleteVersion(song, 'א');
      expect(song.versions.length, 2);
      song = tryDeleteVersion(song, 'ב');
      expect(song.versions.length, 1);
      // Try to delete the last one – should be blocked
      song = tryDeleteVersion(song, 'ג');
      expect(song.versions.length, 1);
      expect(song.versions.containsKey('ג'), isTrue);
    });
  });

  group('Property 8: Minimum One Version – property test (100 inputs)', () {
    test('after any sequence of deletions, at least one version remains', () {
      for (int i = 0; i < 100; i++) {
        final versionCount = (i % 8) + 1; // 1–8 versions
        final versions = Map.fromEntries(
          List.generate(versionCount, (j) => MapEntry('v$j', 'text_$j')),
        );
        var song = _song(versions);

        // Attempt to delete all versions
        for (int j = 0; j < versionCount; j++) {
          final key = 'v$j';
          if (song.versions.containsKey(key)) {
            song = tryDeleteVersion(song, key);
          }
        }

        expect(
          song.versions.length,
          greaterThanOrEqualTo(1),
          reason: 'Iteration $i: song has no versions after deletion attempts',
        );
      }
    });

    test('deletion of non-last version always succeeds', () {
      for (int i = 0; i < 100; i++) {
        final versionCount = (i % 7) + 2; // 2–8 versions (always ≥ 2)
        final versions = Map.fromEntries(
          List.generate(versionCount, (j) => MapEntry('v$j', 'text_$j')),
        );
        final song = _song(versions);
        final result = tryDeleteVersion(song, 'v0');

        expect(
          result.versions.length,
          versionCount - 1,
          reason: 'Iteration $i: deletion of non-last version failed',
        );
        expect(
          result.versions.containsKey('v0'),
          isFalse,
          reason: 'Iteration $i: deleted version still present',
        );
      }
    });
  });
}
