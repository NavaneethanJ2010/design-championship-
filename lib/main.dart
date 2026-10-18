import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'data/database/app_database.dart';
import 'services/ai_summary_service.dart';
import 'services/audio_playback_service_impl.dart';
import 'services/audio_recording_service_impl.dart';
import 'services/lm_studio_config.dart';
import 'services/note_repository_impl.dart';
import 'services/transcription_service_impl.dart';
import 'ui/screens/notes_library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI on desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final database = AppDatabase();
  final noteRepository = NoteRepositoryImpl(database);
  final recordingService = AudioRecordingServiceImpl();
  final playbackService = AudioPlaybackServiceImpl();

  // Configure LM Studio endpoint (handles 127.0.0.1 for Windows and LAN IP for Android)
  final lmConfig = const LmStudioConfig(
    desktopHost: '127.0.0.1',
    androidHost: '10.0.2.2', // Update to laptop Wi-Fi IP (e.g. 192.168.1.X) when testing on a real phone
    port: 1234,
    modelName: 'qwen2.5-7b-instruct',
  );

  final aiSummaryService = AISummaryService(config: lmConfig);
  final transcriptionService = TranscriptionServiceImpl(aiSummaryService: aiSummaryService);

  runApp(WorkshopNotesApp(
    repository: noteRepository,
    recordingService: recordingService,
    playbackService: playbackService,
    transcriptionService: transcriptionService,
  ));
}

class WorkshopNotesApp extends StatelessWidget {
  final NoteRepositoryImpl repository;
  final AudioRecordingServiceImpl recordingService;
  final AudioPlaybackServiceImpl playbackService;
  final TranscriptionServiceImpl transcriptionService;

  const WorkshopNotesApp({
    super.key,
    required this.repository,
    required this.recordingService,
    required this.playbackService,
    required this.transcriptionService,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E88E5);

    return MaterialApp(
      title: 'WorkshopFlow — Offline Notes & Transcribe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: NotesLibraryScreen(
        repository: repository,
        recordingService: recordingService,
        playbackService: playbackService,
        transcriptionService: transcriptionService,
      ),
    );
  }
}
