import 'package:flutter/material.dart';
import '../../domain/repositories/i_note_repository.dart';

class QuestionMarkersWidget extends StatelessWidget {
  final List<QuestionMarkerDto> markers;
  final Function(QuestionMarkerDto marker) onToggleResolved;
  final Function(String markerId) onDeleteMarker;
  final Function(double timestampSeconds)? onSeekToMarker;

  const QuestionMarkersWidget({
    super.key,
    required this.markers,
    required this.onToggleResolved,
    required this.onDeleteMarker,
    this.onSeekToMarker,
  });

  String _formatTimestamp(double seconds) {
    final intSec = seconds.toInt();
    final m = (intSec ~/ 60).toString().padLeft(2, '0');
    final s = (intSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (markers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No questions marked yet. Tap "Mark Question" during recording.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: markers.length,
      itemBuilder: (context, index) {
        final m = markers[index];
        return CheckboxListTile(
          value: m.isResolved,
          onChanged: (val) => onToggleResolved(m.copyWith(isResolved: val ?? false)),
          title: Text(
            m.queryText,
            style: textTheme.bodyMedium?.copyWith(
              decoration: m.isResolved ? TextDecoration.lineThrough : null,
              color: m.isResolved ? colorScheme.outline : null,
            ),
          ),
          secondary: ActionChip(
            label: Text(_formatTimestamp(m.timestampSeconds)),
            onPressed: () => onSeekToMarker?.call(m.timestampSeconds),
          ),
          secondaryPadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          subtitle: m.contextNotes != null ? Text(m.contextNotes!) : null,
        );
      },
    );
  }
}
