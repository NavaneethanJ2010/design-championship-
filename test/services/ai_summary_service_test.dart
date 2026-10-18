import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:workshop_notes/domain/models/ai_summary_models.dart';
import 'package:workshop_notes/services/ai_summary_service.dart';
import 'package:workshop_notes/services/lm_studio_config.dart';

void main() {
  group('AISummaryService Unit Tests', () {
    test('Successfully summarizes short transcript with mocked LM Studio', () async {
      // Mocked OpenAI-compatible chat completion response from LM Studio
      final mockJsonResponse = {
        'id': 'chatcmpl-test-123',
        'object': 'chat.completion',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': jsonEncode({
                'key_takeaways': [
                  'Offline-first architecture improves workshop transcription resilience.',
                  'Drift ORM with SQLite provides cross-platform persistence on Windows and Android.',
                  'LM Studio runs Qwen locally with an OpenAI-compatible REST server.',
                  'Audio files are kept on disk while paths are stored in the DB.',
                  'Android requires LAN IP routing instead of localhost for laptop communication.'
                ],
                'action_items': [
                  'Configure network_security_config.xml on Android for cleartext HTTP.',
                  'Initialize sqfliteFfiInit() on Windows desktop before running queries.'
                ],
                'questions_and_answers': [
                  {
                    'question': 'Can Android call localhost:1234 directly?',
                    'answer': 'No, localhost on Android loops back to the phone itself. Use the host laptop LAN IP.',
                    'is_answer_confirmed': true
                  }
                ],
                'terminology': [
                  {
                    'term': 'WAL Mode',
                    'definition': 'Write-Ahead Logging in SQLite for concurrent reads and writes.',
                    'context': 'Used in database connection setup.'
                  }
                ],
                'uncertain_interpretations': [
                  'Speaker implied Qwen 2.5 7B was preferred, but exact model size was not explicitly confirmed.'
                ]
              })
            },
            'finish_reason': 'stop'
          }
        ]
      };

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/chat/completions');
        return http.Response(jsonEncode(mockJsonResponse), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = AISummaryService(
        client: mockClient,
        config: const LmStudioConfig(desktopHost: '127.0.0.1', port: 1234),
      );

      final summary = await service.summarizeWorkshopTranscript(
        title: 'Offline Workshop Architecture',
        topic: 'Flutter & Local AI',
        fullTranscript: 'Welcome everyone. Today we discuss offline-first architecture with Flutter, SQLite, and Qwen via LM Studio...',
      );

      expect(summary.keyTakeaways.length, 5);
      expect(summary.actionItems.length, 2);
      expect(summary.questionsAndAnswers.first.isAnswerConfirmed, isTrue);
      expect(summary.terminology.first.term, 'WAL Mode');
      expect(summary.uncertainInterpretations.isNotEmpty, isTrue);
    });

    test('Successfully translates spoken Tamil/Tanglish into structured English notes', () async {
      final mockTanglishResponse = {
        'id': 'chatcmpl-tanglish-456',
        'object': 'chat.completion',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': jsonEncode({
                'detected_language': 'Tanglish (Tamil + English)',
                'is_translated': true,
                'translated_language': 'English',
                'key_takeaways': [
                  'Asynchronous state updates ensure that the main UI thread remains completely responsive.',
                  'Loop termination conditions must be verified to prevent infinite execution and memory exhaustion.',
                  'Local SQLite transactions in WAL mode prevent concurrency bottlenecks.',
                  'Audio recording pipelines use native platform buffers without cloud latency.',
                  'Peer-to-peer sync operates over local network hotspots without internet access.'
                ],
                'action_items': [
                  'Implement bounds checking on loop index to eliminate buffer overflows.',
                  'Verify local socket communication on Android emulator port forwarding.'
                ],
                'questions_and_answers': [
                  {
                    'question': 'What happens if the loop termination condition is not satisfied?',
                    'answer': 'The loop will trigger an infinite cycle leading to high CPU usage and potential application freeze.',
                    'is_answer_confirmed': true
                  }
                ],
                'terminology': [
                  {
                    'term': 'Asynchronous State Mutex',
                    'definition': 'A synchronization primitive that prevents simultaneous resource access across concurrent threads.',
                    'context': 'Discussed when explaining thread synchronization.'
                  }
                ],
                'uncertain_interpretations': [
                  'Speaker suggested future support for Bluetooth sync, but this was framed as a future proposal.'
                ]
              })
            },
            'finish_reason': 'stop'
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockTanglishResponse), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = AISummaryService(
        client: mockClient,
        config: const LmStudioConfig(desktopHost: '127.0.0.1', port: 1234),
      );

      final summary = await service.summarizeWorkshopTranscript(
        title: 'Concurrency & Loop Bounds in Algorithms',
        topic: 'Computer Science',
        fullTranscript: 'Indha loop la condition satisfy aagalana infinite ah execute aagum. UI thread block aagama iruka async state use pandrom...',
        translationMode: TranslationMode.autoTamilTanglishToEnglish,
      );

      expect(summary.detectedLanguage, contains('Tanglish'));
      expect(summary.isTranslated, isTrue);
      expect(summary.translatedLanguage, 'English');
      expect(summary.keyTakeaways.length, 5);
      expect(summary.questionsAndAnswers.first.question, contains('loop termination'));
      final formattedMarkdown = summary.toFormattedMarkdown();
      expect(formattedMarkdown, contains('Language Detection & Translation'));
      expect(formattedMarkdown, contains('Translated to: `English (Academic Notes)`'));
    });

    test('Throws LmStudioApiException on invalid JSON output', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Sorry, I am unable to format this as JSON.'}
              }
            ]
          }),
          200,
        );
      });

      final service = AISummaryService(client: mockClient);

      expect(
        () => service.summarizeWorkshopTranscript(
          title: 'Test',
          topic: 'Test',
          fullTranscript: 'Some transcript...',
        ),
        throwsA(isA<LmStudioApiException>()),
      );
    });

    test('Cancellation token halts operation before or during dispatch', () async {
      final mockClient = MockClient((request) async => http.Response('{}', 200));
      final service = AISummaryService(client: mockClient);

      final token = SummaryCancellationToken()..cancel();

      expect(
        () => service.summarizeWorkshopTranscript(
          title: 'Test',
          topic: 'Test',
          fullTranscript: 'Some text',
          cancellationToken: token,
        ),
        throwsA(isA<LmStudioApiException>()),
      );
    });
  });
}
