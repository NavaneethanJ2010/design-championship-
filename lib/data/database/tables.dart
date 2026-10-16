import 'package:drift/drift.dart';

/// Table representing a workshop note.
class WorkshopNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get topic => text().nullable()();
  TextColumn get tags => text().nullable()(); // Stored as comma-separated or JSON list
  TextColumn get summary => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table representing an audio recording session linked to a workshop note.
class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get workshopNoteId => text().references(
        WorkshopNotes,
        #id,
        onDelete: KeyAction.cascade,
        onUpdate: KeyAction.cascade,
      )();
  TextColumn get filePath => text()(); // Absolute or relative path to the persistent audio file
  RealColumn get durationSeconds => real().nullable()();
  TextColumn get audioFormat => text().nullable()(); // e.g., 'm4a', 'wav'
  IntColumn get fileSizeBytes => integer().nullable()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table representing transcript segments generated from an audio recording.
class TranscriptSegments extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId => text().references(
        Recordings,
        #id,
        onDelete: KeyAction.cascade,
        onUpdate: KeyAction.cascade,
      )();
  RealColumn get startSeconds => real()(); // Numeric timestamp in seconds
  RealColumn get endSeconds => real()();   // Numeric timestamp in seconds
  TextColumn get textContent => text()();
  RealColumn get confidence => real().nullable()();
  TextColumn get speaker => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table representing pinned question markers or highlights during a recording.
class QuestionMarkers extends Table {
  TextColumn get id => text()();
  TextColumn get recordingId => text().references(
        Recordings,
        #id,
        onDelete: KeyAction.cascade,
        onUpdate: KeyAction.cascade,
      )();
  RealColumn get timestampSeconds => real()(); // Time offset in seconds where the question occurred
  TextColumn get queryText => text()();
  TextColumn get contextNotes => text().nullable()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
