import 'package:flutter/material.dart';

class SummaryAndNotesCard extends StatelessWidget {
  final TextEditingController takeawaysController;
  final TextEditingController actionItemsController;
  final String? aiSummary;
  final bool isGeneratingSummary;
  final VoidCallback onRequestAiSummary;
  final VoidCallback onContentChanged;

  const SummaryAndNotesCard({
    super.key,
    required this.takeawaysController,
    required this.actionItemsController,
    required this.aiSummary,
    required this.isGeneratingSummary,
    required this.onRequestAiSummary,
    required this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Summary Header & Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Summary',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: isGeneratingSummary ? null : onRequestAiSummary,
                  icon: isGeneratingSummary
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt, size: 16),
                  label: Text(isGeneratingSummary ? 'Summarizing...' : 'Generate Summary'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // AI Summary Content Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                aiSummary != null && aiSummary!.isNotEmpty
                    ? aiSummary!
                    : 'No AI summary generated yet. Tap "Generate Summary" once you have transcript segments.',
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: aiSummary == null ? FontStyle.italic : FontStyle.normal,
                  color: aiSummary == null ? colorScheme.outline : colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Key Takeaways Text Area
            Text(
              'Key Takeaways',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: takeawaysController,
              maxLines: 4,
              onChanged: (_) => onContentChanged(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '• Main insight or key lesson learned...',
              ),
            ),

            const SizedBox(height: 16),

            // Action Items Text Area
            Text(
              'Action Items',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: actionItemsController,
              maxLines: 3,
              onChanged: (_) => onContentChanged(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '☐ Follow up on topic X...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
