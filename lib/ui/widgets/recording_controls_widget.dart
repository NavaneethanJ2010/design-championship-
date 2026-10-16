import 'package:flutter/material.dart';
import '../../domain/services/audio_and_ai_services.dart';

class RecordingControlsWidget extends StatelessWidget {
  final RecordingStatus status;
  final Duration duration;
  final Duration playbackPosition;
  final bool isPlaying;
  final bool hasRecordingFile;
  final VoidCallback onStartRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onPlayPauseAudio;
  final VoidCallback onAddQuestionMarker;

  const RecordingControlsWidget({
    super.key,
    required this.status,
    required this.duration,
    required this.playbackPosition,
    required this.isPlaying,
    required this.hasRecordingFile,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.onStopRecording,
    required this.onPlayPauseAudio,
    required this.onAddQuestionMarker,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            // Timer Display
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  color: status == RecordingStatus.recording
                      ? colorScheme.error
                      : colorScheme.outline,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(duration),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (status != RecordingStatus.idle) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      status.name.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),

            // Action Buttons
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status == RecordingStatus.idle || status == RecordingStatus.stopped)
                  FilledButton.icon(
                    onPressed: onStartRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Record'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                    ),
                  ),

                if (status == RecordingStatus.recording) ...[
                  IconButton.filledTonal(
                    onPressed: onPauseRecording,
                    icon: const Icon(Icons.pause),
                    tooltip: 'Pause recording',
                  ),
                  IconButton.filled(
                    onPressed: onStopRecording,
                    icon: const Icon(Icons.stop),
                    style: IconButton.styleFrom(backgroundColor: colorScheme.error),
                    tooltip: 'Stop recording',
                  ),
                ],

                if (status == RecordingStatus.paused) ...[
                  IconButton.filledTonal(
                    onPressed: onResumeRecording,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Resume recording',
                  ),
                  IconButton.filled(
                    onPressed: onStopRecording,
                    icon: const Icon(Icons.stop),
                    style: IconButton.styleFrom(backgroundColor: colorScheme.error),
                    tooltip: 'Stop recording',
                  ),
                ],

                const SizedBox(width: 8),

                // Question Marker Pin Button
                OutlinedButton.icon(
                  onPressed: (status == RecordingStatus.recording || status == RecordingStatus.paused)
                      ? onAddQuestionMarker
                      : null,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Mark Question'),
                ),

                // Playback Control (Available when audio file is loaded)
                if (hasRecordingFile) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onPlayPauseAudio,
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    tooltip: isPlaying ? 'Pause playback' : 'Play audio',
                  ),
                  Text(
                    _formatDuration(playbackPosition),
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
