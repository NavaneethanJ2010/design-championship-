import 'dart:async';
import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../domain/repositories/i_note_repository.dart';

/// Concrete implementation bridging Drift AppDatabase to INoteRepository.
class NoteRepositoryImpl implements INoteRepository {
  final AppDatabase db;

  NoteRepositoryImpl(this.db);

  @override
  Future<List<WorkshopNoteDto>> getAllWorkshopNotes() async {
    final rows = await (db.select(db.workshopNotes)
          ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .get();
    return rows
        .map(
          (r) => WorkshopNoteDto(
            id: r.id,
            title: r.title,
            topic: r.topic,
            tags: r.tags,
            summary: r.summary,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<WorkshopNoteDto?> getWorkshopNoteById(String noteId) async {
    final r = await db.getWorkshopNoteById(noteId);
    if (r == null) return null;
    return WorkshopNoteDto(
      id: r.id,
      title: r.title,
      topic: r.topic,
      tags: r.tags,
      summary: r.summary,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  @override
  Future<void> saveWorkshopNote(WorkshopNoteDto note) async {
    await db.into(db.workshopNotes).insertOnConflictUpdate(
          WorkshopNotesCompanion(
            id: Value(note.id),
            title: Value(note.title),
            topic: Value(note.topic),
            tags: Value(note.tags),
            summary: Value(note.summary),
            createdAt: Value(note.createdAt),
            updatedAt: Value(note.updatedAt),
          ),
        );
  }

  @override
  Future<void> deleteWorkshopNote(String noteId) async {
    await db.deleteWorkshopNote(noteId);
  }

  @override
  Future<String?> getActiveRecordingForNote(String noteId) async {
    final rec = await (db.select(db.recordings)..where((tbl) => tbl.workshopNoteId.equals(noteId))).getSingleOrNull();
    return rec?.id;
  }

  @override
  Future<void> saveWorkshopHeader({
    required String noteId,
    required String title,
    required String speaker,
    required String topic,
    required DateTime date,
  }) async {
    final existing = await db.getWorkshopNoteById(noteId);
    if (existing == null) {
      await db.into(db.workshopNotes).insert(
            WorkshopNotesCompanion.insert(
              id: noteId,
              title: title,
              topic: Value(topic),
              tags: Value(speaker), // We can store speaker in tags or dedicated field
              createdAt: Value(date),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (db.update(db.workshopNotes)..where((tbl) => tbl.id.equals(noteId))).write(
        WorkshopNotesCompanion(
          title: Value(title),
          topic: Value(topic),
          tags: Value(speaker),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  @override
  Future<void> saveNotesContent({
    required String noteId,
    required String takeaways,
    required String actionItems,
    String? aiSummary,
  }) async {
    // Encapsulate takeaways & action items in summary or structured JSON
    final combinedNotes = 'TAKEAWAYS:\n$takeaways\n\nACTIONS:\n$actionItems';
    await (db.update(db.workshopNotes)..where((tbl) => tbl.id.equals(noteId))).write(
      WorkshopNotesCompanion(
        summary: Value(aiSummary ?? combinedNotes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> saveTranscriptSegment(TranscriptSegmentDto segment) async {
    await db.into(db.transcriptSegments).insertOnConflictUpdate(
          TranscriptSegmentsCompanion.insert(
            id: segment.id,
            recordingId: segment.recordingId,
            startSeconds: segment.startSeconds,
            endSeconds: segment.endSeconds,
            textContent: segment.textContent,
            confidence: Value(segment.confidence),
            speaker: Value(segment.speaker),
          ),
        );
  }

  @override
  Future<void> saveQuestionMarker(QuestionMarkerDto marker) async {
    await db.into(db.questionMarkers).insertOnConflictUpdate(
          QuestionMarkersCompanion.insert(
            id: marker.id,
            recordingId: marker.recordingId,
            timestampSeconds: marker.timestampSeconds,
            queryText: marker.queryText,
            contextNotes: Value(marker.contextNotes),
            isResolved: Value(marker.isResolved),
          ),
        );
  }

  @override
  Future<List<TranscriptSegmentDto>> getTranscriptSegments(String recordingId) async {
    final segments = await db.getSegmentsForRecording(recordingId);
    return segments
        .map(
          (s) => TranscriptSegmentDto(
            id: s.id,
            recordingId: s.recordingId,
            startSeconds: s.startSeconds,
            endSeconds: s.endSeconds,
            textContent: s.textContent,
            speaker: s.speaker,
            confidence: s.confidence,
          ),
        )
        .toList();
  }

  @override
  Future<List<QuestionMarkerDto>> getQuestionMarkers(String recordingId) async {
    final markers = await db.getQuestionMarkersForRecording(recordingId);
    return markers
        .map(
          (m) => QuestionMarkerDto(
            id: m.id,
            recordingId: m.recordingId,
            timestampSeconds: m.timestampSeconds,
            queryText: m.queryText,
            contextNotes: m.contextNotes,
            isResolved: m.isResolved,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteQuestionMarker(String markerId) async {
    await (db.delete(db.questionMarkers)..where((tbl) => tbl.id.equals(markerId))).go();
  }
}
