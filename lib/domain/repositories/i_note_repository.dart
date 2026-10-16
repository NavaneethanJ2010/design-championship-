import 'dart:async';

/// Data transfer model for transcript segments.
class TranscriptSegmentDto {
  final String id;
  final String recordingId;
  final double startSeconds;
  final double endSeconds;
  final String textContent;
  final String? speaker;
  final double? confidence;

  TranscriptSegmentDto({
    required this.id,
    required this.recordingId,
    required this.startSeconds,
    required this.endSeconds,
    required this.textContent,
    this.speaker,
    this.confidence,
  });

  TranscriptSegmentDto copyWith({
    String? textContent,
    String? speaker,
  }) {
    return TranscriptSegmentDto(
      id: id,
      recordingId: recordingId,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      textContent: textContent ?? this.textContent,
      speaker: speaker ?? this.speaker,
      confidence: confidence,
    );
  }
}

/// Data transfer model for question markers.
class QuestionMarkerDto {
  final String id;
  final String recordingId;
  final double timestampSeconds;
  final String queryText;
  final String? contextNotes;
  final bool isResolved;

  QuestionMarkerDto({
    required this.id,
    required this.recordingId,
    required this.timestampSeconds,
    required this.queryText,
    this.contextNotes,
    this.isResolved = false,
  });

  QuestionMarkerDto copyWith({
    String? queryText,
    String? contextNotes,
    bool? isResolved,
  }) {
    return QuestionMarkerDto(
      id: id,
      recordingId: recordingId,
      timestampSeconds: timestampSeconds,
      queryText: queryText ?? this.queryText,
      contextNotes: contextNotes ?? this.contextNotes,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}

/// Core interface for note, recording, segment, and marker persistence.
abstract class INoteRepository {
  Future<void> saveWorkshopHeader({
    required String noteId,
    required String title,
    required String speaker,
    required String topic,
    required DateTime date,
  });

  Future<void> saveNotesContent({
    required String noteId,
    required String takeaways,
    required String actionItems,
    String? aiSummary,
  });

  Future<void> saveTranscriptSegment(TranscriptSegmentDto segment);

  Future<void> saveQuestionMarker(QuestionMarkerDto marker);

  Future<List<TranscriptSegmentDto>> getTranscriptSegments(String recordingId);

  Future<List<QuestionMarkerDto>> getQuestionMarkers(String recordingId);

  Future<void> deleteQuestionMarker(String markerId);
}
