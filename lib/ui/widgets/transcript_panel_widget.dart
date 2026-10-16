import 'package:flutter/material.dart';
import '../../domain/repositories/i_note_repository.dart';

class TranscriptPanelWidget extends StatelessWidget {
  final List<TranscriptSegmentDto> segments;
  final Function(TranscriptSegmentDto updated) onSegmentEdited;
  final Function(double timestampSeconds)? onSeekToTimestamp;

  const TranscriptPanelWidget({
    super.key,
    required this.segments,
    required this.onSegmentEdited,
    this.onSeekToTimestamp,
  });

  String _formatTimestamp(double seconds) {
    final intSec = seconds.toInt();
    final m = (intSec ~/ 60).toString().padLeft(2, '0');
    final s = (intSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showEditDialog(BuildContext context, TranscriptSegmentDto segment) {
    final controller = TextEditingController(text: segment.textContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Segment [${_formatTimestamp(segment.startSeconds)}]'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter corrected transcript text...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onSegmentEdited(segment.copyWith(textContent: controller.text.trim()));
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.transcribe_outlined, size: 48, color: colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'No transcript segments available',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                'Audio recorded will be processed via local transcription.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: segments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final seg = segments[index];
        return ListTile(
          leading: ActionChip(
            avatar: const Icon(Icons.play_circle_outline, size: 16),
            label: Text(
              _formatTimestamp(seg.startSeconds),
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => onSeekToTimestamp?.call(seg.startSeconds),
          ),
          title: Text(
            seg.textContent,
            style: textTheme.bodyMedium,
          ),
          subtitle: seg.speaker != null ? Text('Speaker: ${seg.speaker}') : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit_note, size: 20),
            tooltip: 'Edit text',
            onPressed: () => _showEditDialog(context, seg),
          ),
        );
      },
    );
  }
}
