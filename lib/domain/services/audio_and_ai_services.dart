enum RecordingStatus { idle, recording, paused, stopped }

abstract class IAudioRecordingService {
  Stream<RecordingStatus> get statusStream;
  Stream<Duration> get durationStream;
  Duration get currentDuration;
  RecordingStatus get status;

  Future<void> startRecording({required String destinationPath});
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<String?> stopRecording();
  void dispose();
}

abstract class IAudioPlaybackService {
  Stream<Duration> get positionStream;
  Stream<bool> get isPlayingStream;
  Duration get currentPosition;

  Future<void> loadAudio(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  void dispose();
}

abstract class ITranscriptionService {
  Stream<TranscriptSegmentDto> get segmentStream;
  Future<String> requestAiSummary({
    required String title,
    required String topic,
    required List<String> transcriptLines,
  });
}
