import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    // Platform-specific persistent directory retrieval
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workshop_notes.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // Enforce SQLite Foreign Key constraints
        rawDb.execute('PRAGMA foreign_keys = ON;');
        // Enable WAL mode for high performance concurrent offline read/writes
        rawDb.execute('PRAGMA journal_mode = WAL;');
      },
    );
  });
}
