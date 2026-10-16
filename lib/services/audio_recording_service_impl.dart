import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../domain/services/audio_and_ai_services.dart';

/// Concrete implementation of audio recording across Windows & Android using the `record` package.
class AudioRecordingServiceImpl implements IAudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  final _statusController = StreamController<RecordingStatus>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  RecordingStatus _status = RecordingStatus.idle;
  Duration _currentDuration = Duration.zero;
  Timer? _timer;
  String? _currentRecordingPath;

  AudioRecordingServiceImpl() {
    _statusController.add(_status);
    _durationController.add(_currentDuration);
  }

  @override
  Stream<RecordingStatus> get statusStream => _statusController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Duration get currentDuration => _currentDuration;

  @override
  RecordingStatus get status => _status;

  @override
  Future<void> startRecording({required String destinationPath}) async {
    // Request microphone permissions on mobile (Android)
    if (Platform.isAndroid) {
      final permStatus = await Permission.microphone.request();
      if (!permStatus.isGranted) {
        throw Exception('Microphone permission not granted.');
      }
    }

    // Check device recorder permissions via record package
    if (!await _recorder.hasPermission()) {
      throw Exception('Recording permission denied by OS.');
    }

    // Resolve storage folder
    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(directory.path, 'recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final fullPath = p.join(recordingsDir.path, destinationPath);
    _currentRecordingPath = fullPath;

    // Use AAC LC for high quality and small file size across Android and Windows MediaFoundation
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      bitRate: 128000,
    );

    await _recorder.start(config, path: fullPath);

    _status = RecordingStatus.recording;
    _statusController.add(_status);
    _currentDuration = Duration.zero;
    _durationController.add(_currentDuration);

    _startTimer();
  }

  @override
  Future<void> pauseRecording() async {
    if (_status == RecordingStatus.recording) {
      await _recorder.pause();
      _status = RecordingStatus.paused;
      _statusController.add(_status);
      _timer?.cancel();
    }
  }

  @override
  Future<void> resumeRecording() async {
    if (_status == RecordingStatus.paused) {
      await _recorder.resume();
      _status = RecordingStatus.recording;
      _statusController.add(_status);
      _startTimer();
    }
  }

  @override
  Future<String?> stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    _status = RecordingStatus.stopped;
    _statusController.add(_status);
    return path ?? _currentRecordingPath;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration += const Duration(seconds: 1);
      _durationController.add(_currentDuration);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _statusController.close();
    _durationController.close();
  }
}
