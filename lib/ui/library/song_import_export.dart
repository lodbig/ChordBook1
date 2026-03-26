import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/song.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/repositories/tag_repository.dart';

/// Exports [songs] to a JSON file.
/// Tags are exported as names (not IDs) for portability.
/// - Windows: opens Save dialog via file_picker.
/// - Android: writes to temp dir and shares via share_plus.
/// Returns true on success.
Future<bool> exportSongsToJson(
  BuildContext context,
  List<Song> songs,
) async {
  if (songs.isEmpty) return false;

  // Resolve tag IDs → names for portability
  final tagRepo = TagRepository();
  final allTags = await tagRepo.getAll();
  final tagIdToName = {for (final t in allTags) t.id: t.name};

  final exportList = songs.map((s) {
    final json = s.toJson();
    json['tags'] = s.tags.map((id) => tagIdToName[id] ?? id).toList();
    return json;
  }).toList();

  final jsonStr = const JsonEncoder.withIndent('  ').convert(exportList);
  final bytes = utf8.encode(jsonStr);

  if (Platform.isWindows) {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'שמור קובץ שירים',
      fileName: 'chordbook_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path != null) {
      await File(path).writeAsBytes(bytes);
    }
    return path != null;
  } else {
    // Android: שתף את הקובץ דרך share_plus (עובד בכל גרסאות Android)
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/chordbook_export.json');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'ChordBook שירים',
    );
    return true;
  }
}

/// Imports songs from a JSON file chosen by the user.
/// Deduplicates by song ID (existing songs are not overwritten).
/// Creates missing tags referenced by imported songs.
/// Shows a summary dialog on completion.
Future<void> importSongsFromJson(
  BuildContext context,
  SongRepository repo,
  VoidCallback onImported,
) async {
  // ב-Android: נסה עם סינון JSON, אם לא עובד – פתח כל קובץ
  FilePickerResult? result;
  if (Platform.isAndroid) {
    result = await FilePicker.platform.pickFiles(
      dialogTitle: 'בחר קובץ שירים לייבוא',
      type: FileType.any,
      withData: true,
    );
  } else {
    result = await FilePicker.platform.pickFiles(
      dialogTitle: 'בחר קובץ שירים לייבוא',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
  }

  if (result == null || result.files.isEmpty) return;

  final pickedFile = result.files.first;
  Uint8List? fileBytes = pickedFile.bytes;

  if (fileBytes == null && pickedFile.path != null) {
    fileBytes = await File(pickedFile.path!).readAsBytes();
  }

  if (fileBytes == null) return;

  List<dynamic> jsonList;
  try {
    jsonList = jsonDecode(utf8.decode(fileBytes)) as List<dynamic>;
  } catch (e) {
    if (context.mounted) {
      _showErrorDialog(context, 'קובץ JSON לא תקין: $e');
    }
    return;
  }

  final existing = await repo.getAll();
  final existingIds = existing.map((s) => s.id).toSet();

  // Load existing tags and build name→id map
  final tagRepo = TagRepository();
  final existingTags = await tagRepo.getAll();
  final tagByName = <String, Tag>{for (final t in existingTags) t.name: t};

  int imported = 0;
  int skipped = 0;

  for (final item in jsonList) {
    try {
      final song = Song.fromJson(item as Map<String, dynamic>);

      // Ensure all tag IDs referenced by the song exist.
      // The exported JSON stores tag IDs in song.tags, but we don't have
      // the tag names in the song model. So we treat unknown IDs as tag names
      // (fallback: create a tag whose name == the unknown id string).
      final resolvedTagIds = <String>[];
      for (final tagId in song.tags) {
        // Check if tag already exists by ID
        final existsById = existingTags.any((t) => t.id == tagId) ||
            tagByName.values.any((t) => t.id == tagId);
        if (existsById) {
          resolvedTagIds.add(tagId);
        } else {
          // Treat the tagId as a tag name and create if needed
          if (tagByName.containsKey(tagId)) {
            resolvedTagIds.add(tagByName[tagId]!.id);
          } else {
            final newTag = Tag(id: const Uuid().v4(), name: tagId);
            await tagRepo.save(newTag);
            tagByName[tagId] = newTag;
            existingTags.add(newTag);
            resolvedTagIds.add(newTag.id);
          }
        }
      }

      final resolvedSong = song.copyWith(tags: resolvedTagIds);

      if (existingIds.contains(resolvedSong.id)) {
        skipped++;
      } else {
        await repo.save(resolvedSong);
        imported++;
      }
    } catch (_) {
      skipped++;
    }
  }

  onImported();

  if (context.mounted) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ייבוא הושלם'),
        content: Text('יובאו $imported שירים.\nדולגו $skipped (כפולים או שגויים).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }
}

void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('שגיאת ייבוא'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('סגור'),
        ),
      ],
    ),
  );
}
