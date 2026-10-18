import 'dart:async';

import '../domain/models/ai_summary_models.dart';
import '../domain/repositories/i_note_repository.dart';
import '../domain/services/audio_and_ai_services.dart';
import 'ai_summary_service.dart';

/// Concrete transcription and AI summarization adapter bridging AISummaryService to UI.
class TranscriptionServiceImpl implements ITranscriptionService {
  final AISummaryService aiSummaryService;
  final _segmentController = StreamController<TranscriptSegmentDto>.broadcast();

  TranscriptionServiceImpl({required this.aiSummaryService});

  @override
  Stream<TranscriptSegmentDto> get segmentStream => _segmentController.stream;

  /// External voice transcription engines (like local Whisper or Vosk)
  /// push live decoded segments through this method.
  void emitSegment(TranscriptSegmentDto segment) {
    _segmentController.add(segment);
  }

  @override
  Future<String> requestAiSummary({
    required String title,
    required String topic,
    required List<String> transcriptLines,
    TranslationMode translationMode = TranslationMode.autoTamilTanglishToEnglish,
  }) async {
    final combinedTranscript = transcriptLines.join('\n');
    final structuredSummary = await aiSummaryService.summarizeWorkshopTranscript(
      title: title,
      topic: topic,
      fullTranscript: combinedTranscript,
      translationMode: translationMode,
    );
    return structuredSummary.toFormattedMarkdown();
  }

  void dispose() {
    _segmentController.close();
  }
}
