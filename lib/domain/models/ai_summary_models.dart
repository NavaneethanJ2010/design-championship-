import 'dart:convert';

/// Question and Answer pair identified from the workshop.
class QuestionAnswerItem {
  final String question;
  final String answer;
  final bool isAnswerConfirmed; // True if explicitly answered, false if inferred/uncertain

  QuestionAnswerItem({
    required this.question,
    required this.answer,
    this.isAnswerConfirmed = true,
  });

  factory QuestionAnswerItem.fromJson(Map<String, dynamic> json) {
    return QuestionAnswerItem(
      question: json['question'] as String? ?? 'Unknown Question',
      answer: json['answer'] as String? ?? 'No direct answer identified.',
      isAnswerConfirmed: json['is_answer_confirmed'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'is_answer_confirmed': isAnswerConfirmed,
      };
}

/// Terminology item containing key terms, jargon, or acronyms explained in the session.
class TerminologyItem {
  final String term;
  final String definition;
  final String context;

  TerminologyItem({
    required this.term,
    required this.definition,
    this.context = '',
  });

  factory TerminologyItem.fromJson(Map<String, dynamic> json) {
    return TerminologyItem(
      term: json['term'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      context: json['context'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'definition': definition,
        'context': context,
      };
}

/// Structured AI summary returned after local processing with Qwen / LM Studio.
class WorkshopStructuredSummary {
  final List<String> keyTakeaways; // Exactly 5 primary takeaways
  final List<String> actionItems;
  final List<QuestionAnswerItem> questionsAndAnswers;
  final List<TerminologyItem> terminology;
  final List<String> uncertainInterpretations; // Explicitly separates inferred insights from stated facts
  final String rawPromptContext;

  WorkshopStructuredSummary({
    required this.keyTakeaways,
    required this.actionItems,
    required this.questionsAndAnswers,
    required this.terminology,
    this.uncertainInterpretations = const [],
    this.rawPromptContext = '',
  });

  factory WorkshopStructuredSummary.fromJson(Map<String, dynamic> json) {
    final takeawaysRaw = json['key_takeaways'] as List<dynamic>? ?? [];
    final actionItemsRaw = json['action_items'] as List<dynamic>? ?? [];
    final qaRaw = json['questions_and_answers'] as List<dynamic>? ?? [];
    final termsRaw = json['terminology'] as List<dynamic>? ?? [];
    final uncertainRaw = json['uncertain_interpretations'] as List<dynamic>? ?? [];

    return WorkshopStructuredSummary(
      keyTakeaways: takeawaysRaw.map((e) => e.toString()).toList(),
      actionItems: actionItemsRaw.map((e) => e.toString()).toList(),
      questionsAndAnswers: qaRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => QuestionAnswerItem.fromJson(e))
          .toList(),
      terminology: termsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => TerminologyItem.fromJson(e))
          .toList(),
      uncertainInterpretations: uncertainRaw.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key_takeaways': keyTakeaways,
        'action_items': actionItems,
        'questions_and_answers': questionsAndAnswers.map((e) => e.toJson()).toList(),
        'terminology': terminology.map((e) => e.toJson()).toList(),
        'uncertain_interpretations': uncertainInterpretations,
      };

  String toFormattedMarkdown() {
    final buffer = StringBuffer();

    buffer.writeln('### 💡 5 Key Takeaways');
    for (int i = 0; i < keyTakeaways.length; i++) {
      buffer.writeln('${i + 1}. ${keyTakeaways[i]}');
    }

    buffer.writeln('\n### ✅ Action Items');
    if (actionItems.isEmpty) {
      buffer.writeln('_None identified._');
    } else {
      for (final item in actionItems) {
        buffer.writeln('- [ ] $item');
      }
    }

    buffer.writeln('\n### ❓ Questions & Answers');
    if (questionsAndAnswers.isEmpty) {
      buffer.writeln('_No explicit Q&A found._');
    } else {
      for (final qa in questionsAndAnswers) {
        buffer.writeln('**Q:** ${qa.question}');
        buffer.writeln('**A:** ${qa.answer} ${qa.isAnswerConfirmed ? "" : "*(Inferred/Uncertain)*"}\n');
      }
    }

    buffer.writeln('### 📖 Important Terminology');
    if (terminology.isEmpty) {
      buffer.writeln('_No distinct terms highlighted._');
    } else {
      for (final term in terminology) {
        buffer.writeln('- **${term.term}**: ${term.definition}');
      }
    }

    if (uncertainInterpretations.isNotEmpty) {
      buffer.writeln('\n### ⚠️ Inferred / Uncertain Interpretations');
      for (final un in uncertainInterpretations) {
        buffer.writeln('- $un');
      }
    }

    return buffer.toString();
  }
}
