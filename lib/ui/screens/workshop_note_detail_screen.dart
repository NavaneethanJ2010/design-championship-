import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/repositories/i_note_repository.dart';
import '../../domain/services/audio_and_ai_services.dart';
import '../widgets/question_markers_widget.dart';
import '../widgets/recording_controls_widget.dart';
import '../widgets/summary_and_notes_card.dart';
import '../widgets/transcript_panel_widget.dart';

class WorkshopNoteDetailScreen extends StatefulWidget {
  final String noteId;
  final String? initialRecordingId;
  final INoteRepository repository;
  final IAudioRecordingService recordingService;
  final IAudioPlaybackService playbackService;
  final ITranscriptionService transcriptionService;

  const WorkshopNoteDetailScreen({
    super.key,
    required this.noteId,
    this.initialRecordingId,
    required this.repository,
    required this.recordingService,
    required this.playbackService,
    required this.transcriptionService,
  });

  @override
  State<WorkshopNoteDetailScreen> createState() => _WorkshopNoteDetailScreenState();
}

class _WorkshopNoteDetailScreenState extends State<WorkshopNoteDetailScreen> {
  // Text Editing Controllers for Note Header and Content
  late final TextEditingController _titleController;
  late final TextEditingController _speakerController;
  late final TextEditingController _topicController;
  late final TextEditingController _takeawaysController;
  late final TextEditingController _actionItemsController;

  DateTime _workshopDate = DateTime.now();
  String? _currentRecordingId;
  String? _recordedAudioFilePath;
  String? _aiSummary;
  bool _isGeneratingSummary = false;

  // Save State and Error Feedback
  bool _isSaving = false;
  String? _saveErrorMessage;
  DateTime? _lastSavedAt;
  Timer? _autoSaveDebounceTimer;

  // Streams & Dynamic State
  List<TranscriptSegmentDto> _segments = [];
  List<QuestionMarkerDto> _markers = [];
  RecordingStatus _recordingStatus = RecordingStatus.idle;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  bool _isPlayingAudio = false;

  late final StreamSubscription<RecordingStatus> _statusSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<Duration> _playbackPosSub;
  late final StreamSubscription<bool> _isPlayingSub;
  late final StreamSubscription<TranscriptSegmentDto> _transcriptSub;

  @override
  void initState() {
    super.initState();
    _currentRecordingId = widget.initialRecordingId;

    _titleController = TextEditingController();
    _speakerController = TextEditingController();
    _topicController = TextEditingController();
    _takeawaysController = TextEditingController();
    _actionItemsController = TextEditingController();

    _initSubscriptions();
    _loadInitialData();
  }

  void _initSubscriptions() {
    _statusSub = widget.recordingService.statusStream.listen((status) {
      if (mounted) setState(() => _recordingStatus = status);
    });

    _durationSub = widget.recordingService.durationStream.listen((duration) {
      if (mounted) setState(() => _recordingDuration = duration);
    });

    _playbackPosSub = widget.playbackService.positionStream.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });

    _isPlayingSub = widget.playbackService.isPlayingStream.listen((playing) {
      if (mounted) setState(() => _isPlayingAudio = playing);
    });

    // Influx of live transcript segments from transcription service
    _transcriptSub = widget.transcriptionService.segmentStream.listen((newSegment) {
      if (mounted) {
        setState(() {
          _segments.add(newSegment);
        });
        // Auto-persist new segment to SQLite
        widget.repository.saveTranscriptSegment(newSegment);
      }
    });
  }

  Future<void> _loadInitialData() async {
    if (_currentRecordingId != null) {
      try {
        final segments = await widget.repository.getTranscriptSegments(_currentRecordingId!);
        final markers = await widget.repository.getQuestionMarkers(_currentRecordingId!);
        if (mounted) {
          setState(() {
            _segments = segments;
            _markers = markers;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _saveErrorMessage = 'Error loading recording data: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _autoSaveDebounceTimer?.cancel();
    _statusSub.cancel();
    _durationSub.cancel();
    _playbackPosSub.cancel();
    _isPlayingSub.cancel();
    _transcriptSub.cancel();

    _titleController.dispose();
    _speakerController.dispose();
    _topicController.dispose();
    _takeawaysController.dispose();
    _actionItemsController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // AUTO-SAVE LOGIC
  // ---------------------------------------------------------------------------
  void _onContentChanged() {
    _autoSaveDebounceTimer?.cancel();
    _autoSaveDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _saveAllChanges();
    });
  }

  Future<void> _saveAllChanges() async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      await widget.repository.saveWorkshopHeader(
        noteId: widget.noteId,
        title: _titleController.text.trim().isEmpty ? 'Untitled Workshop' : _titleController.text.trim(),
        speaker: _speakerController.text.trim(),
        topic: _topicController.text.trim(),
        date: _workshopDate,
      );

      await widget.repository.saveNotesContent(
        noteId: widget.noteId,
        takeaways: _takeawaysController.text,
        actionItems: _actionItemsController.text,
        aiSummary: _aiSummary,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _lastSavedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = 'Failed to save changes: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RECORDING ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _handleStartRecording() async {
    try {
      final targetPath = 'recording_${widget.noteId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await widget.recordingService.startRecording(destinationPath: targetPath);
    } catch (e) {
      setState(() => _saveErrorMessage = 'Recording start failed: $e');
    }
  }

  Future<void> _handlePauseRecording() async {
    await widget.recordingService.pauseRecording();
  }

  Future<void> _handleResumeRecording() async {
    await widget.recordingService.resumeRecording();
  }

  Future<void> _handleStopRecording() async {
    try {
      final savedPath = await widget.recordingService.stopRecording();
      if (savedPath != null) {
        setState(() {
          _recordedAudioFilePath = savedPath;
        });
        await widget.playbackService.loadAudio(savedPath);
      }
    } catch (e) {
      setState(() => _saveErrorMessage = 'Failed stopping recording: $e');
    }
  }

  void _handlePlayPauseAudio() {
    if (_isPlayingAudio) {
      widget.playbackService.pause();
    } else {
      widget.playbackService.play();
    }
  }

  // ---------------------------------------------------------------------------
  // QUESTION MARKER ACTION
  // ---------------------------------------------------------------------------
  void _handleAddQuestionMarker() {
    final curSeconds = _recordingDuration.inMilliseconds / 1000.0;
    final textEdit = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Question Marker'),
        content: TextField(
          controller: textEdit,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'What question was asked?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final query = textEdit.text.trim();
              if (query.isNotEmpty) {
                final marker = QuestionMarkerDto(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  recordingId: _currentRecordingId ?? 'active_session',
                  timestampSeconds: curSeconds,
                  queryText: query,
                );
                setState(() => _markers.add(marker));
                await widget.repository.saveQuestionMarker(marker);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Mark'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI SUMMARY ACTION
  // ---------------------------------------------------------------------------
  Future<void> _handleGenerateAiSummary() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot summarize without transcript segments.')),
      );
      return;
    }

    setState(() => _isGeneratingSummary = true);
    try {
      final summary = await widget.transcriptionService.requestAiSummary(
        title: _titleController.text,
        topic: _topicController.text,
        transcriptLines: _segments.map((s) => s.textContent).toList(),
      );

      setState(() {
        _aiSummary = summary;
        _isGeneratingSummary = false;
      });
      _onContentChanged();
    } catch (e) {
      setState(() {
        _isGeneratingSummary = false;
        _saveErrorMessage = 'AI Summary error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleController.text.isEmpty ? 'Workshop Note' : _titleController.text),
        actions: [
          // Save status indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _lastSavedAt != null
                          ? 'Saved ${DateFormat.Hm().format(_lastSavedAt!)}'
                          : 'Unsaved',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Prominent Error Banner
            if (_saveErrorMessage != null)
              MaterialBanner(
                backgroundColor: colorScheme.errorContainer,
                content: Text(
                  _saveErrorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _saveErrorMessage = null),
                    child: const Text('DISMISS'),
                  ),
                ],
              ),

            // Top Persistent Recording Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: RecordingControlsWidget(
                status: _recordingStatus,
                duration: _recordingDuration,
                playbackPosition: _playbackPosition,
                isPlaying: _isPlayingAudio,
                hasRecordingFile: _recordedAudioFilePath != null,
                onStartRecording: _handleStartRecording,
                onPauseRecording: _handlePauseRecording,
                onResumeRecording: _handleResumeRecording,
                onStopRecording: _handleStopRecording,
                onPlayPauseAudio: _handlePlayPauseAudio,
                onAddQuestionMarker: _handleAddQuestionMarker,
              ),
            ),

            // Responsive Layout Body
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 840;

                  return isDesktop
                      ? _buildDesktopLayout(colorScheme, textTheme)
                      : _buildMobileLayout(colorScheme, textTheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP TWO-PANE LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Metadata, Takeaways, Action Items, Summary
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMetadataCard(colorScheme),
                  const SizedBox(height: 16),
                  SummaryAndNotesCard(
                    takeawaysController: _takeawaysController,
                    actionItemsController: _actionItemsController,
                    aiSummary: _aiSummary,
                    isGeneratingSummary: _isGeneratingSummary,
                    onRequestAiSummary: _handleGenerateAiSummary,
                    onContentChanged: _onContentChanged,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Right Pane: Transcript & Question Markers
          Expanded(
            flex: 6,
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Live Timestamped Transcript',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TranscriptPanelWidget(
                      segments: _segments,
                      onSegmentEdited: (updated) {
                        setState(() {
                          final idx = _segments.indexWhere((s) => s.id == updated.id);
                          if (idx != -1) _segments[idx] = updated;
                        });
                        widget.repository.saveTranscriptSegment(updated);
                      },
                      onSeekToTimestamp: (sec) {
                        widget.playbackService.seek(Duration(milliseconds: (sec * 1000).toInt()));
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Questions Asked', style: textTheme.labelLarge),
                  ),
                  SizedBox(
                    height: 160,
                    child: QuestionMarkersWidget(
                      markers: _markers,
                      onToggleResolved: (m) {
                        setState(() {
                          final idx = _markers.indexWhere((it) => it.id == m.id);
                          if (idx != -1) _markers[idx] = m;
                        });
                        widget.repository.saveQuestionMarker(m);
                      },
                      onDeleteMarker: (id) {
                        setState(() => _markers.removeWhere((it) => it.id == id));
                        widget.repository.deleteQuestionMarker(id);
                      },
                      onSeekToMarker: (sec) {
                        widget.playbackService.seek(Duration(milliseconds: (sec * 1000).toInt()));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE SINGLE-COLUMN TABS LAYOUT
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(ColorScheme colorScheme, TextTheme textTheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notes), text: 'Notes & Summary'),
              Tab(icon: Icon(Icons.transcribe), text: 'Transcript & Qs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetadataCard(colorScheme),
                      const SizedBox(height: 16),
                      SummaryAndNotesCard(
                        takeawaysController: _takeawaysController,
                        actionItemsController: _actionItemsController,
                        aiSummary: _aiSummary,
                        isGeneratingSummary: _isGeneratingSummary,
                        onRequestAiSummary: _handleGenerateAiSummary,
                        onContentChanged: _onContentChanged,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(
                        child: TranscriptPanelWidget(
                          segments: _segments,
                          onSegmentEdited: (updated) {
                            setState(() {
                              final idx = _segments.indexWhere((s) => s.id == updated.id);
                              if (idx != -1) _segments[idx] = updated;
                            });
                            widget.repository.saveTranscriptSegment(updated);
                          },
                        ),
                      ),
                      const Divider(),
                      SizedBox(
                        height: 140,
                        child: QuestionMarkersWidget(
                          markers: _markers,
                          onToggleResolved: (m) {
                            setState(() {
                              final idx = _markers.indexWhere((it) => it.id == m.id);
                              if (idx != -1) _markers[idx] = m;
                            });
                            widget.repository.saveQuestionMarker(m);
                          },
                          onDeleteMarker: (id) {
                            setState(() => _markers.removeWhere((it) => it.id == id));
                            widget.repository.deleteQuestionMarker(id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              onChanged: (_) => _onContentChanged(),
              decoration: const InputDecoration(
                labelText: 'Workshop Title',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speakerController,
                    onChanged: (_) => _onContentChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Speaker Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    onChanged: (_) => _onContentChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _workshopDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _workshopDate = picked);
                  _onContentChanged();
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat.yMMMd().format(_workshopDate)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
