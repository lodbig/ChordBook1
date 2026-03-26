import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book_template.dart';
import '../models/custom_chord.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/tag.dart';

class DatabaseManager {
  DatabaseManager._();

  static bool _initialized = false;

  /// Initialize Hive with the correct platform-specific path and register all adapters.
  ///
  /// - Windows: path relative to the executable directory
  /// - Android: internal app storage (documents directory)
  static Future<void> initialize() async {
    if (_initialized) return;

    final dbPath = await _resolveDatabasePath();

    // נסה לפתוח - אם נכשל בגלל lock, מחק את קבצי ה-lock ונסה שוב
    try {
      await Hive.initFlutter(dbPath);
    } catch (_) {
      await _clearLockFiles(dbPath);
      await Hive.initFlutter(dbPath);
    }

    _registerAdapters();
    _initialized = true;
  }

  static Future<void> _clearLockFiles(String dbPath) async {
    try {
      final dir = Directory(dbPath);
      if (!await dir.exists()) return;
      await for (final file in dir.list()) {
        if (file.path.endsWith('.lock')) {
          try { await file.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(SongAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlaylistAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TagAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CustomChordAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(IndexOptionsAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(BookSectionAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SectionDividerAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(SongEntryAdapter());
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(BookTemplateAdapter());
  }

  static Future<String> _resolveDatabasePath() async {
    if (Platform.isWindows) {
      // AppData\Roaming\ChordBook – תמיד יש הרשאות כתיבה
      final appSupportDir = await getApplicationSupportDirectory();
      final dbDir = p.join(appSupportDir.path, 'chordbook_data');
      await Directory(dbDir).create(recursive: true);
      return dbDir;
    } else {
      // Android: internal storage דרך path_provider
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbDir = p.join(appDocDir.path, 'chordbook_data');
      await Directory(dbDir).create(recursive: true);
      return dbDir;
    }
  }

  /// Open a named Hive box, initializing the database first if needed.
  static Future<Box<T>> openBox<T>(String name) async {
    await initialize();
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  /// Close all open Hive boxes.
  static Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }

  /// Returns the database directory path (for export/import).
  static Future<String> getDatabasePath() async {
    return _resolveDatabasePath();
  }
}
