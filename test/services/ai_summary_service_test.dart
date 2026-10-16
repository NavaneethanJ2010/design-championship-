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
