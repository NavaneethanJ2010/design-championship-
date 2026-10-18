import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/i_note_repository.dart';
import '../../domain/services/audio_and_ai_services.dart';
import '../../services/offline_sync_service.dart';
import 'workshop_note_detail_screen.dart';

class NotesLibraryScreen extends StatefulWidget {
  final INoteRepository repository;
  final IAudioRecordingService recordingService;
  final IAudioPlaybackService playbackService;
  final ITranscriptionService transcriptionService;

  const NotesLibraryScreen({
    super.key,
    required this.repository,
    required this.recordingService,
    required this.playbackService,
    required this.transcriptionService,
  });

  @override
  State<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

class _NotesLibraryScreenState extends State<NotesLibraryScreen> {
  List<WorkshopNoteDto> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late final OfflineSyncService _syncService;

  final List<String> _categories = [
    'All',
    'Full-Stack',
    'AI & Deep Learning',
    'Robotics & IoT',
    'Algorithms',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _syncService = OfflineSyncService(repository: widget.repository);
    _loadNotes();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.repository.getAllWorkshopNotes();
      if (mounted) {
        setState(() {
          _notes = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkshopNoteDto> get _filteredNotes {
    return _notes.where((note) {
      final matchesSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (note.topic?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (note.tags?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesCategory = _selectedCategory == 'All' ||
          (note.topic != null && note.topic!.toLowerCase().contains(_selectedCategory.toLowerCase()));

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _openNote(String noteId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopNoteDetailScreen(
          noteId: noteId,
          repository: widget.repository,
          recordingService: widget.recordingService,
          playbackService: widget.playbackService,
          transcriptionService: widget.transcriptionService,
        ),
      ),
    );
    _loadNotes();
  }

  void _createNewNote() async {
    final newId = const Uuid().v4();
    final newNote = WorkshopNoteDto(
      id: newId,
      title: 'New Workshop Session',
      topic: _selectedCategory == 'All' ? 'General' : _selectedCategory,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await widget.repository.saveWorkshopNote(newNote);
    _openNote(newId);
  }

  void _showSyncModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sync, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Offline P2P Device Sync', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Direct Wi-Fi / Hotspot peer-to-peer sync between Android & Windows. Zero cloud, 100% offline.',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 16),

                  // Server state switch
                  Card(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Local Sync Server',
                                style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Switch(
                                value: _syncService.isServerRunning,
                                onChanged: (val) async {
                                  if (val) {
                                    await _syncService.startServer();
                                  } else {
                                    await _syncService.stopServer();
                                  }
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                          if (_syncService.isServerRunning) ...[
                            const SizedBox(height: 8),
                            FutureBuilder<List<String>>(
                              future: _syncService.getLocalIpAddresses(),
                              builder: (context, snapshot) {
                                final ips = snapshot.data ?? ['Detecting...'];
                                return Text(
                                  'Server Active at: http://${ips.first}:${_syncService.serverPort}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('Connect to Peer Device', style: textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'http://192.168.43.1:8089',
                            labelText: 'Peer URL',
                            isDense: true,
                          ),
                          onSubmitted: (peerUrl) async {
                            if (_notes.isNotEmpty && peerUrl.isNotEmpty) {
                              final success = await _syncService.pushNoteToPeer(peerUrl, _notes.first.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(success ? 'Synced successfully!' : 'Peer connection failed')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_none, size: 20, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Text(
              'WorkshopFlow',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: _showSyncModal,
            icon: const Icon(Icons.sync, size: 20),
            tooltip: 'Offline P2P Sync',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewNote,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search workshop notes, topics, or transcripts...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() => _selectedCategory = category);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Notes List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_alt_outlined, size: 56, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              'No workshop notes found',
                              style: textTheme.titleMedium?.copyWith(color: colorScheme.outline),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap "+ New Session" below to start taking notes.',
                              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = _filteredNotes[index];
                          final hasSummary = note.summary != null && note.summary!.isNotEmpty;
                          final isTamilTranslated = hasSummary &&
                              (note.summary!.contains('Tamil') || note.summary!.contains('Tanglish'));

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openNote(note.id),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          DateFormat.yMMMd().format(note.createdAt),
                                          style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      note.topic ?? 'General Topic',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        if (isTamilTranslated)
                                          Chip(
                                            avatar: const Icon(Icons.translate, size: 14),
                                            label: const Text('Tamil ➔ English Translated'),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                        if (hasSummary && !isTamilTranslated)
                                          Chip(
                                            avatar: const Icon(Icons.auto_awesome, size: 14),
                                            label: const Text('AI Synthesized'),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                        Chip(
                                          avatar: const Icon(Icons.schedule, size: 14),
                                          label: Text('Updated ${DateFormat.jm().format(note.updatedAt)}'),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
