import 'package:flutter/material.dart';
import '../../domain/models/ai_summary_models.dart';

class SummaryAndNotesCard extends StatefulWidget {
  final TextEditingController takeawaysController;
  final TextEditingController actionItemsController;
  final String? aiSummary;
  final bool isGeneratingSummary;
  final void Function(TranslationMode mode)? onRequestAiSummaryWithMode;
  final VoidCallback onRequestAiSummary;
  final VoidCallback onContentChanged;

  const SummaryAndNotesCard({
    super.key,
    required this.takeawaysController,
    required this.actionItemsController,
    required this.aiSummary,
    required this.isGeneratingSummary,
    this.onRequestAiSummaryWithMode,
    required this.onRequestAiSummary,
    required this.onContentChanged,
  });

  @override
  State<SummaryAndNotesCard> createState() => _SummaryAndNotesCardState();
}

class _SummaryAndNotesCardState extends State<SummaryAndNotesCard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TranslationMode _selectedMode = TranslationMode.autoTamilTanglishToEnglish;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _triggerGeneration() {
    if (widget.onRequestAiSummaryWithMode != null) {
      widget.onRequestAiSummaryWithMode!(_selectedMode);
    } else {
      widget.onRequestAiSummary();
    }
  }

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
            // AI Summary Header & Translation Mode Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'AI Synthesis & Translation',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.isGeneratingSummary ? null : _triggerGeneration,
                  icon: widget.isGeneratingSummary
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt, size: 16),
                  label: Text(
                    widget.isGeneratingSummary ? 'Translating & Synthesizing...' : 'Translate & Generate',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Translation Mode Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Language Mode:',
                    style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TranslationMode>(
                        value: _selectedMode,
                        isExpanded: true,
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: TranslationMode.values.map((mode) {
                          return DropdownMenuItem<TranslationMode>(
                            value: mode,
                            child: Text(mode.label),
                          );
                        }).toList(),
                        onChanged: (newMode) {
                          if (newMode != null) {
                            setState(() => _selectedMode = newMode);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.isGeneratingSummary) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],

            const SizedBox(height: 12),

            // Tab bar for AI Output vs Manual Cornell Notes
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.menu_book, size: 18), text: 'AI Notes & Translation'),
                Tab(icon: Icon(Icons.lightbulb_outline, size: 18), text: 'Takeaways'),
                Tab(icon: Icon(Icons.check_circle_outline, size: 18), text: 'Action Items'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab View Body
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: AI Summary & Translated Markdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: widget.aiSummary != null && widget.aiSummary!.isNotEmpty
                        ? SingleChildScrollView(
                            child: SelectableText(
                              widget.aiSummary!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.translate, size: 36, color: colorScheme.outline),
                                const SizedBox(height: 8),
                                Text(
                                  'Tamil/Tanglish auto-detected and translated to English.\nTap "Translate & Generate" to process recorded transcript segments.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // Tab 2: Key Takeaways Cornell Text Area
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Key Takeaways (High-Impact Insights)',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: TextField(
                          controller: widget.takeawaysController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          onChanged: (_) => widget.onContentChanged(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '1. Autonomous translation preserves Tamil concepts in proper English.\n2. In-app execution requires no cloud dependencies...',
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tab 3: Action Items Checklist
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action Items & Follow-ups',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: TextField(
                          controller: widget.actionItemsController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          onChanged: (_) => widget.onContentChanged(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '☐ Review lecture formula derivations\n☐ Run test script on local GPU',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
