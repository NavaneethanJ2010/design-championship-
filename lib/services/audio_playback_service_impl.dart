import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

import '../domain/services/audio_and_ai_services.dart';

/// Concrete implementation of audio playback for Windows & Android using audioplayers.
class AudioPlaybackServiceImpl implements IAudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  final _positionController = StreamController<Duration>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();

  Duration _currentPosition = Duration.zero;
  late final StreamSubscription _posSub;
  late final StreamSubscription _stateSub;

  AudioPlaybackServiceImpl() {
    _posSub = _player.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      _positionController.add(pos);
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _isPlayingController.add(state == PlayerState.playing);
    });
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Future<void> loadAudio(String filePath) async {
    await _player.setSource(DeviceFileSource(filePath));
  }

  @override
  Future<void> play() async {
    await _player.resume();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  void dispose() {
    _posSub.cancel();
    _stateSub.cancel();
    _player.dispose();
    _positionController.close();
    _isPlayingController.close();
  }
}
