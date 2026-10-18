import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../domain/repositories/i_note_repository.dart';

/// Service managing offline peer-to-peer (P2P) sync between Android phone and Windows laptop
/// via local Wi-Fi or phone Mobile Hotspot without requiring any internet connection.
class OfflineSyncService {
  HttpServer? _server;
  int _port = 8089;
  final http.Client _client = http.Client();
  final INoteRepository repository;

  OfflineSyncService({required this.repository});

  bool get isServerRunning => _server != null;
  int get serverPort => _port;

  /// Retrieves non-loopback local network IP (e.g. 192.168.43.x on hotspot)
  Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }
    return ips;
  }

  /// Starts the embedded zero-cloud HTTP sync server on this device.
  Future<String> startServer({int port = 8089}) async {
    if (_server != null) {
      await stopServer();
    }
    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _listenToRequests(_server!);
      final ips = await getLocalIpAddresses();
      return 'http://${ips.first}:$_port';
    } catch (e) {
      throw Exception('Failed to start offline P2P sync server on port $_port: $e');
    }
  }

  /// Stops the local sync server.
  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _listenToRequests(HttpServer server) {
    server.listen((HttpRequest request) async {
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path;

      try {
        if (path == '/api/status' && request.method == 'GET') {
          // Handshake endpoint
          final statusPayload = {
            'app': 'WorkshopFlow',
            'version': '1.0.0',
            'device': Platform.operatingSystem,
            'status': 'ready',
            'timestamp': DateTime.now().toIso8601String(),
          };
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode(statusPayload));
        } else if (path == '/api/sync/pull' && request.method == 'GET') {
          // Peer pulling a note bundle
          final noteId = request.uri.queryParameters['noteId'];
          if (noteId == null || noteId.isEmpty) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write('Missing noteId parameter');
          } else {
            final bundleJson = await exportNoteBundle(noteId);
            request.response
              ..headers.contentType = ContentType.json
              ..statusCode = HttpStatus.ok
              ..write(bundleJson);
          }
        } else if (path == '/api/sync/push' && request.method == 'POST') {
          // Peer pushing a note bundle
          final bodyString = await utf8.decodeStream(request);
          final bundleMap = jsonDecode(bodyString) as Map<String, dynamic>;
          await importNoteBundle(bundleMap);

          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'success': true, 'message': 'Note bundle imported successfully.'}));
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Endpoint not found');
        }
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Sync error: $e');
      } finally {
        await request.response.close();
      }
    });
  }

  /// Exports an entire workshop note with all transcripts and question markers into `.wnote` JSON
  Future<String> exportNoteBundle(String noteId) async {
    final note = await repository.getWorkshopNoteById(noteId);
    final recording = await repository.getActiveRecordingForNote(noteId);
    final segments = await repository.getTranscriptSegmentsForNote(noteId);
    final markers = await repository.getQuestionMarkersForNote(noteId);

    final bundle = {
      'format': 'wnote',
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'note': note != null
          ? {
              'id': note.id,
              'title': note.title,
              'topic': note.topic,
              'tags': note.tags,
              'summary': note.summary,
              'createdAt': note.createdAt.toIso8601String(),
              'updatedAt': note.updatedAt.toIso8601String(),
            }
          : null,
      'recording': recording != null
          ? {
              'id': recording.id,
              'workshopNoteId': recording.workshopNoteId,
              'filePath': recording.filePath,
              'durationSeconds': recording.durationSeconds,
              'audioFormat': recording.audioFormat,
              'fileSizeBytes': recording.fileSizeBytes,
              'recordedAt': recording.recordedAt.toIso8601String(),
            }
          : null,
      'segments': segments
          .map((s) => {
                'id': s.id,
                'recordingId': s.recordingId,
                'startSeconds': s.startSeconds,
                'endSeconds': s.endSeconds,
                'textContent': s.textContent,
                'confidence': s.confidence,
                'speaker': s.speaker,
                'createdAt': s.createdAt.toIso8601String(),
              })
          .toList(),
      'markers': markers
          .map((m) => {
                'id': m.id,
                'recordingId': m.recordingId,
                'timestampSeconds': m.timestampSeconds,
                'queryText': m.queryText,
                'contextNotes': m.contextNotes,
                'isResolved': m.isResolved,
                'createdAt': m.createdAt.toIso8601String(),
              })
          .toList(),
    };

    return jsonEncode(bundle);
  }

  /// Imports a `.wnote` bundle map into the local database
  Future<void> importNoteBundle(Map<String, dynamic> bundle) async {
    final noteData = bundle['note'] as Map<String, dynamic>?;
    if (noteData != null) {
      final noteDto = WorkshopNoteDto(
        id: noteData['id'] as String? ?? const Uuid().v4(),
        title: noteData['title'] as String? ?? 'Imported Workshop',
        topic: noteData['topic'] as String?,
        tags: noteData['tags'] as String?,
        summary: noteData['summary'] as String?,
        createdAt: noteData['createdAt'] != null
            ? DateTime.tryParse(noteData['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveWorkshopNote(noteDto);
    }

    final segmentsData = bundle['segments'] as List<dynamic>? ?? [];
    for (final seg in segmentsData) {
      if (seg is Map<String, dynamic>) {
        final segmentDto = TranscriptSegmentDto(
          id: seg['id'] as String? ?? const Uuid().v4(),
          recordingId: seg['recordingId'] as String? ?? '',
          startSeconds: (seg['startSeconds'] as num?)?.toDouble() ?? 0.0,
          endSeconds: (seg['endSeconds'] as num?)?.toDouble() ?? 0.0,
          textContent: seg['textContent'] as String? ?? '',
          confidence: (seg['confidence'] as num?)?.toDouble(),
          speaker: seg['speaker'] as String?,
          createdAt: seg['createdAt'] != null
              ? DateTime.tryParse(seg['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
        await repository.saveTranscriptSegment(segmentDto);
      }
    }

    final markersData = bundle['markers'] as List<dynamic>? ?? [];
    for (final m in markersData) {
      if (m is Map<String, dynamic>) {
        final markerDto = QuestionMarkerDto(
          id: m['id'] as String? ?? const Uuid().v4(),
          recordingId: m['recordingId'] as String? ?? '',
          timestampSeconds: (m['timestampSeconds'] as num?)?.toDouble() ?? 0.0,
          queryText: m['queryText'] as String? ?? 'Question',
          contextNotes: m['contextNotes'] as String?,
          isResolved: m['isResolved'] as bool? ?? false,
          createdAt: m['createdAt'] != null
              ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
        await repository.saveQuestionMarker(markerDto);
      }
    }
  }

  /// Pushes a note from this device to peer device via direct local URL
  Future<bool> pushNoteToPeer(String peerUrl, String noteId) async {
    final bundleJson = await exportNoteBundle(noteId);
    final normalizedUrl = peerUrl.endsWith('/') ? '${peerUrl}api/sync/push' : '$peerUrl/api/sync/push';
    final response = await _client.post(
      Uri.parse(normalizedUrl),
      headers: {'Content-Type': 'application/json'},
      body: bundleJson,
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == HttpStatus.ok;
  }

  /// Pulls a note from peer device via direct local URL
  Future<bool> pullNoteFromPeer(String peerUrl, String noteId) async {
    final normalizedUrl = peerUrl.endsWith('/') ? '${peerUrl}api/sync/pull?noteId=$noteId' : '$peerUrl/api/sync/pull?noteId=$noteId';
    final response = await _client.get(
      Uri.parse(normalizedUrl),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == HttpStatus.ok) {
      final bundleMap = jsonDecode(response.body) as Map<String, dynamic>;
      await importNoteBundle(bundleMap);
      return true;
    }
    return false;
  }

  void dispose() {
    _server?.close(force: true);
    _client.close();
  }
}
