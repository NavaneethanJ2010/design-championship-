import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    WorkshopNotes,
    Recordings,
    TranscriptSegments,
    QuestionMarkers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Create custom indices for rapid search performance
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_search ON workshop_notes(title, topic, tags);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_segments_text ON transcript_segments(text_content);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_segments_recording ON transcript_segments(recording_id, start_seconds);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_markers_recording ON question_markers(recording_id, timestamp_seconds);',
          );
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Safe migration handling template
          if (from < 1) {
            await m.createAll();
          }
        },
        beforeOpen: (details) async {
          // Additional integrity checks or seeding if needed
        },
      );

  // ---------------------------------------------------------------------------
  // WORKSHOP NOTES DAO / METHODS
  // ---------------------------------------------------------------------------

  Future<String> createWorkshopNote({
    required String title,
    String? topic,
    String? tags,
    String? summary,
    String? customId,
  }) async {
    final noteId = customId ?? _uuid.v4();
    final now = DateTime.now();

    await into(workshopNotes).insert(
      WorkshopNotesCompanion.insert(
        id: noteId,
        title: title,
        topic: Value(topic),
        tags: Value(tags),
        summary: Value(summary),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return noteId;
  }

  Future<WorkshopNote?> getWorkshopNoteById(String id) {
    return (select(workshopNotes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<List<WorkshopNote>> watchAllWorkshopNotes() {
    return (select(workshopNotes)
          ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<bool> updateWorkshopNote({
    required String id,
    String? title,
    String? topic,
    String? tags,
    String? summary,
  }) async {
    final result = await (update(workshopNotes)..where((tbl) => tbl.id.equals(id))).write(
      WorkshopNotesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        topic: Value(topic),
        tags: Value(tags),
        summary: Value(summary),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return result > 0;
  }

  Future<int> deleteWorkshopNote(String id) {
    // Foreign key cascade configured in schema automatically removes recordings,
    // transcript segments, and question markers.
    return (delete(workshopNotes)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // RECORDINGS DAO / METHODS
  // ---------------------------------------------------------------------------

  Future<String> createRecording({
    required String workshopNoteId,
    required String filePath,
    double? durationSeconds,
    String? audioFormat,
    int? fileSizeBytes,
    String? customId,
  }) async {
    final recordingId = customId ?? _uuid.v4();
    await into(recordings).insert(
      RecordingsCompanion.insert(
        id: recordingId,
        workshopNoteId: workshopNoteId,
        filePath: filePath,
        durationSeconds: Value(durationSeconds),
        audioFormat: Value(audioFormat),
        fileSizeBytes: Value(fileSizeBytes),
        recordedAt: Value(DateTime.now()),
      ),
    );
    return recordingId;
  }

  Future<Recording?> getRecordingById(String id) {
    return (select(recordings)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<Recording>> getRecordingsForNote(String noteId) {
    return (select(recordings)
          ..where((tbl) => tbl.workshopNoteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
        .get();
  }

  Future<int> deleteRecording(String id) {
    return (delete(recordings)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // TRANSCRIPT SEGMENTS DAO / METHODS
  // ---------------------------------------------------------------------------

  Future<String> addTranscriptSegment({
    required String recordingId,
    required double startSeconds,
    required double endSeconds,
    required String textContent,
    double? confidence,
    String? speaker,
    String? customId,
  }) async {
    final segmentId = customId ?? _uuid.v4();
    await into(transcriptSegments).insert(
      TranscriptSegmentsCompanion.insert(
        id: segmentId,
        recordingId: recordingId,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
        textContent: textContent,
        confidence: Value(confidence),
        speaker: Value(speaker),
      ),
    );
    return segmentId;
  }

  /// Bulk insert transcript segments in a single transaction (ideal for LM Studio streaming batch outputs)
  Future<void> insertTranscriptSegmentsBatch({
    required String recordingId,
    required List<({double start, double end, String text, double? confidence, String? speaker})>
        segments,
  }) async {
    await transaction(() async {
      await batch((batch) {
        batch.insertAll(
          transcriptSegments,
          segments.map(
            (s) => TranscriptSegmentsCompanion.insert(
              id: _uuid.v4(),
              recordingId: recordingId,
              startSeconds: s.start,
              endSeconds: s.end,
              textContent: s.text,
              confidence: Value(s.confidence),
              speaker: Value(s.speaker),
            ),
          ),
        );
      });
    });
  }

  Future<List<TranscriptSegment>> getSegmentsForRecording(String recordingId) {
    return (select(transcriptSegments)
          ..where((tbl) => tbl.recordingId.equals(recordingId))
          ..orderBy([(t) => OrderingTerm.asc(t.startSeconds)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // QUESTION MARKERS DAO / METHODS
  // ---------------------------------------------------------------------------

  Future<String> addQuestionMarker({
    required String recordingId,
    required double timestampSeconds,
    required String queryText,
    String? contextNotes,
    String? customId,
  }) async {
    final markerId = customId ?? _uuid.v4();
    await into(questionMarkers).insert(
      QuestionMarkersCompanion.insert(
        id: markerId,
        recordingId: recordingId,
        timestampSeconds: timestampSeconds,
        queryText: queryText,
        contextNotes: Value(contextNotes),
      ),
    );
    return markerId;
  }

  Future<bool> setQuestionMarkerResolved(String id, bool isResolved) async {
    final count = await (update(questionMarkers)..where((tbl) => tbl.id.equals(id))).write(
      QuestionMarkersCompanion(
        isResolved: Value(isResolved),
      ),
    );
    return count > 0;
  }

  Future<List<QuestionMarker>> getQuestionMarkersForRecording(String recordingId) {
    return (select(questionMarkers)
          ..where((tbl) => tbl.recordingId.equals(recordingId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestampSeconds)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // TRANSACTIONAL COMPOSITE WRITES
  // ---------------------------------------------------------------------------

  /// Transactionally creates a workshop note, attaches an initial recording,
  /// and sets up question markers and initial transcript segments together safely.
  Future<({String noteId, String recordingId})> createNoteWithRecordingAndSegments({
    required String title,
    String? topic,
    String? tags,
    required String audioFilePath,
    double? durationSeconds,
    List<({double start, double end, String text})>? initialSegments,
    List<({double timestamp, String query})>? initialMarkers,
  }) async {
    return transaction(() async {
      final noteId = _uuid.v4();
      final recordingId = _uuid.v4();
      final now = DateTime.now();

      await into(workshopNotes).insert(
        WorkshopNotesCompanion.insert(
          id: noteId,
          title: title,
          topic: Value(topic),
          tags: Value(tags),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await into(recordings).insert(
        RecordingsCompanion.insert(
          id: recordingId,
          workshopNoteId: noteId,
          filePath: audioFilePath,
          durationSeconds: Value(durationSeconds),
          recordedAt: Value(now),
        ),
      );

      if (initialSegments != null && initialSegments.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            transcriptSegments,
            initialSegments.map(
              (s) => TranscriptSegmentsCompanion.insert(
                id: _uuid.v4(),
                recordingId: recordingId,
                startSeconds: s.start,
                endSeconds: s.end,
                textContent: s.text,
              ),
            ),
          );
        });
      }

      if (initialMarkers != null && initialMarkers.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            questionMarkers,
            initialMarkers.map(
              (m) => QuestionMarkersCompanion.insert(
                id: _uuid.v4(),
                recordingId: recordingId,
                timestampSeconds: m.timestamp,
                queryText: m.query,
              ),
            ),
          );
        });
      }

      return (noteId: noteId, recordingId: recordingId);
    });
  }

  // ---------------------------------------------------------------------------
  // SEARCH QUERIES (Titles, Topics, Tags, Transcript Text)
  // ---------------------------------------------------------------------------

  /// Performs an offline search across notes (title, topic, tags) and their transcripts.
  Future<List<WorkshopNote>> searchNotes(String searchTerm) async {
    final queryTerm = '%$searchTerm%';

    final noteQuery = select(workshopNotes).join([
      leftOuterJoin(
        recordings,
        recordings.workshopNoteId.equalsExp(workshopNotes.id),
      ),
      leftOuterJoin(
        transcriptSegments,
        transcriptSegments.recordingId.equalsExp(recordings.id),
      ),
    ])
      ..where(
        workshopNotes.title.like(queryTerm) |
            workshopNotes.topic.like(queryTerm) |
            workshopNotes.tags.like(queryTerm) |
            transcriptSegments.textContent.like(queryTerm),
      )
      ..groupBy([workshopNotes.id]);

    final rows = await noteQuery.get();
    return rows.map((row) => row.readTable(workshopNotes)).toList();
  }
}
