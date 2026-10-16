import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../domain/models/ai_summary_models.dart';
import 'lm_studio_config.dart';

/// Exception thrown when the LM Studio API cannot be reached or returns an error.
class LmStudioApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  LmStudioApiException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => 'LmStudioApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Token/cancellation controller for active summarization operations.
class SummaryCancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Service that interacts with a locally hosted Qwen LLM via LM Studio.
class AISummaryService {
  final http.Client _client;
  final LmStudioConfig config;

  AISummaryService({
    http.Client? client,
    this.config = const LmStudioConfig(),
  }) : _client = client ?? http.Client();

  /// Health-check to verify LM Studio is running and responding locally.
  Future<bool> checkConnection() async {
    try {
      final response = await _client
          .get(config.modelsUri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Generates a structured summary for the provided transcript text.
  /// Handles chunking for long transcripts and returns a consolidated summary.
  Future<WorkshopStructuredSummary> summarizeWorkshopTranscript({
    required String title,
    required String topic,
    required String fullTranscript,
    SummaryCancellationToken? cancellationToken,
  }) async {
    if (fullTranscript.trim().isEmpty) {
      throw LmStudioApiException('Cannot summarize an empty transcript.');
    }

    // 1. Chunk transcript if it exceeds configured limit
    final chunks = _splitTranscriptWithOverlap(
      fullTranscript,
      maxChars: config.maxChunkChars,
      overlapChars: config.chunkOverlapChars,
    );

    if (chunks.length == 1) {
      return _generateStructuredSummaryForText(
        title: title,
        topic: topic,
        transcriptContent: chunks.first,
        cancellationToken: cancellationToken,
      );
    }

    // 2. Multi-chunk handling: summarize each chunk, then synthesize
    final intermediateSummaries = <WorkshopStructuredSummary>[];

    for (int i = 0; i < chunks.length; i++) {
      if (cancellationToken?.isCancelled == true) {
        throw LmStudioApiException('Summarization cancelled by user.');
      }

      final partialSummary = await _generateStructuredSummaryForText(
        title: '$title (Part ${i + 1}/${chunks.length})',
        topic: topic,
        transcriptContent: chunks[i],
        cancellationToken: cancellationToken,
      );
      intermediateSummaries.add(partialSummary);
    }

    // 3. Final consolidation pass
    return _synthesizeIntermediateSummaries(
      title: title,
      topic: topic,
      intermediateSummaries: intermediateSummaries,
      cancellationToken: cancellationToken,
    );
  }

  /// Internal request to Qwen LLM with strict JSON schema instructions.
  Future<WorkshopStructuredSummary> _generateStructuredSummaryForText({
    required String title,
    required String topic,
    required String transcriptContent,
    SummaryCancellationToken? cancellationToken,
  }) async {
    final systemPrompt = '''
You are an expert technical workshop analyst and scribe.
Analyze the provided transcript segment and extract key information.

STRICT REQUIREMENTS:
1. Return ONLY a valid JSON object matching the requested schema. No markdown fences (```json), no conversational filler.
2. Distinguish verified facts explicitly stated by the speaker from inferences. Place inferences in "uncertain_interpretations".
3. Extract EXACTLY 5 high-impact "key_takeaways".
4. Extract explicit "action_items".
5. Extract explicit "questions_and_answers". If an answer is unclear or inferred, set "is_answer_confirmed" to false.
6. Extract specialized "terminology" defined or emphasized.

JSON SCHEMA:
{
  "key_takeaways": ["Takeaway 1", "Takeaway 2", "Takeaway 3", "Takeaway 4", "Takeaway 5"],
  "action_items": ["Action 1", "Action 2"],
  "questions_and_answers": [
    {
      "question": "Question text?",
      "answer": "Answer text",
      "is_answer_confirmed": true
    }
  ],
  "terminology": [
    {
      "term": "Term",
      "definition": "Definition or explanation given",
      "context": "Context where term was used"
    }
  ],
  "uncertain_interpretations": ["Interpretation that was not 100% verified"]
}
''';

    final userPrompt = '''
Workshop Title: $title
Topic: $topic

Transcript Segment:
"""
$transcriptContent
"""
''';

    final requestBody = {
      'model': config.modelName,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.2, // Low temperature for deterministic factual extraction
      'response_format': {'type': 'json_object'},
    };

    if (cancellationToken?.isCancelled == true) {
      throw LmStudioApiException('Operation was cancelled before dispatch.');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            config.chatCompletionsUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(config.timeout);
    } on SocketException catch (e) {
      throw LmStudioApiException(
        'Unable to connect to local LM Studio at ${config.baseUrl}. '
        'Verify LM Studio is running, Local Server is ON, and check your IP settings.',
        cause: e,
      );
    } on TimeoutException catch (e) {
      throw LmStudioApiException(
        'LM Studio request timed out after ${config.timeout.inSeconds} seconds. '
        'Consider increasing the timeout or checking laptop GPU load.',
        cause: e,
      );
    } catch (e) {
      throw LmStudioApiException('Unexpected network error communicating with LM Studio: $e', cause: e);
    }

    if (response.statusCode != 200) {
      throw LmStudioApiException(
        'LM Studio server error: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return _parseAndValidateJsonResponse(response.body);
  }

  /// Synthesizes intermediate chunk summaries into one cohesive final summary.
  Future<WorkshopStructuredSummary> _synthesizeIntermediateSummaries({
    required String title,
    required String topic,
    required List<WorkshopStructuredSummary> intermediateSummaries,
    SummaryCancellationToken? cancellationToken,
  }) async {
    final intermediateJsonList = intermediateSummaries.map((s) => s.toJson()).toList();
    final combinedContext = jsonEncode(intermediateJsonList);

    final synthesisPrompt = '''
You are synthesizing multiple partial summaries from consecutive sections of the workshop "$title" (Topic: $topic).

Consolidate the following intermediate summaries into a SINGLE cohesive final summary.
Select the top 5 most critical "key_takeaways" across the entire workshop.
Merge all unique action items, Q&A pairs, and terminology definitions without duplicates.

Return ONLY a valid JSON object matching the standard schema.
''';

    final requestBody = {
      'model': config.modelName,
      'messages': [
        {'role': 'system', 'content': synthesisPrompt},
        {'role': 'user', 'content': combinedContext},
      ],
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
    };

    final response = await _client
        .post(
          config.chatCompletionsUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(config.timeout);

    if (response.statusCode != 200) {
      throw LmStudioApiException(
        'Failed to synthesize multi-chunk summaries: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return _parseAndValidateJsonResponse(response.body);
  }

  /// Validates and parses the JSON response from Qwen.
  WorkshopStructuredSummary _parseAndValidateJsonResponse(String responseBody) {
    try {
      final decodedRoot = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = decodedRoot['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        throw LmStudioApiException('LM Studio returned empty choices array.');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final rawContent = message?['content'] as String?;

      if (rawContent == null || rawContent.trim().isEmpty) {
        throw LmStudioApiException('Received empty message content from LM Studio.');
      }

      // Clean common markdown fences if model inadvertently included them
      String sanitized = rawContent.trim();
      if (sanitized.startsWith('```json')) {
        sanitized = sanitized.substring(7);
      }
      if (sanitized.startsWith('```')) {
        sanitized = sanitized.substring(3);
      }
      if (sanitized.endsWith('```')) {
        sanitized = sanitized.substring(0, sanitized.length - 3);
      }
      sanitized = sanitized.trim();

      final summaryJson = jsonDecode(sanitized) as Map<String, dynamic>;

      // Validate required keys exist
      if (!summaryJson.containsKey('key_takeaways')) {
        throw LmStudioApiException('Model JSON response is missing "key_takeaways" array.');
      }

      return WorkshopStructuredSummary.fromJson(summaryJson);
    } on FormatException catch (e) {
      throw LmStudioApiException(
        'Model generated invalid JSON output. Response text: $responseBody',
        cause: e,
      );
    }
  }

  /// Splits long transcripts into overlapping chunks without breaking mid-sentence.
  List<String> _splitTranscriptWithOverlap(
    String text, {
    required int maxChars,
    required int overlapChars,
  }) {
    if (text.length <= maxChars) {
      return [text];
    }

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + maxChars;
      if (end >= text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }

      // Try finding a natural punctuation break (. or \n) to avoid chopping sentences
      int breakIndex = text.lastIndexOf('\n', end);
      if (breakIndex <= start) {
        breakIndex = text.lastIndexOf('. ', end);
      }
      if (breakIndex <= start) {
        breakIndex = end; // Fallback to character boundary
      } else {
        breakIndex += 1; // Include period or newline
      }

      chunks.add(text.substring(start, breakIndex).trim());

      // Advance start pointer with overlap
      start = (breakIndex - overlapChars).clamp(0, text.length);
      if (start <= chunks.length - 1) {
        // Prevent infinite loops if breakIndex didn't advance enough
        start = breakIndex;
      }
    }

    return chunks;
  }

  void dispose() {
    _client.close();
  }
}
