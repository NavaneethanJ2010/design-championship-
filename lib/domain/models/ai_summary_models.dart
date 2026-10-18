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

enum TranslationMode {
  autoTamilTanglishToEnglish,
  directEnglish,
  preserveBilingual;

  String get label {
    switch (this) {
      case TranslationMode.autoTamilTanglishToEnglish:
        return 'Auto-Detect & Translate to English (Tamil / Tanglish)';
      case TranslationMode.directEnglish:
        return 'Direct English Analysis';
      case TranslationMode.preserveBilingual:
        return 'Preserve Original Spoken Language';
    }
  }
}

/// Structured AI summary returned after local processing with Qwen / LM Studio.
class WorkshopStructuredSummary {
  final List<String> keyTakeaways; // Exactly 5 primary takeaways
  final List<String> actionItems;
  final List<QuestionAnswerItem> questionsAndAnswers;
  final List<TerminologyItem> terminology;
  final List<String> uncertainInterpretations; // Explicitly separates inferred insights from stated facts
  final String rawPromptContext;
  final String detectedLanguage;
  final bool isTranslated;
  final String translatedLanguage;

  WorkshopStructuredSummary({
    required this.keyTakeaways,
    required this.actionItems,
    required this.questionsAndAnswers,
    required this.terminology,
    this.uncertainInterpretations = const [],
    this.rawPromptContext = '',
    this.detectedLanguage = 'English',
    this.isTranslated = false,
    this.translatedLanguage = 'English',
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
      detectedLanguage: json['detected_language'] as String? ?? 'English',
      isTranslated: json['is_translated'] as bool? ?? (json['detected_language'] != null && json['detected_language'] != 'English'),
      translatedLanguage: json['translated_language'] as String? ?? 'English',
    );
  }

  Map<String, dynamic> toJson() => {
        'key_takeaways': keyTakeaways,
        'action_items': actionItems,
        'questions_and_answers': questionsAndAnswers.map((e) => e.toJson()).toList(),
        'terminology': terminology.map((e) => e.toJson()).toList(),
        'uncertain_interpretations': uncertainInterpretations,
        'detected_language': detectedLanguage,
        'is_translated': isTranslated,
        'translated_language': translatedLanguage,
      };

  String toFormattedMarkdown() {
    final buffer = StringBuffer();

    if (isTranslated || detectedLanguage.toLowerCase().contains('tamil') || detectedLanguage.toLowerCase().contains('tanglish')) {
      buffer.writeln('> 🌐 **Language Detection & Translation**');
      buffer.writeln('> Spoken Language: `$detectedLanguage` ➔ Translated to: `$translatedLanguage (Academic Notes)`\n');
    }

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
