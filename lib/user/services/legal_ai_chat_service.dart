import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class LegalAiChatService {
  LegalAiChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  _LegalAiConfig? _config;
  List<_LegalDatasetItem> _dataset = const [];
  DateTime? _lastLoadedAt;

  Future<LegalAiReply> reply({
    required String userInput,
    required List<LegalAiHistoryMessage> history,
  }) async {
    if (!_isLegalQuestion(userInput)) {
      return const LegalAiReply(
        text:
            'I can only help with legal topics. Please ask a legal question about contracts, courts, rights, family law, property, labor, criminal law, or procedures.',
      );
    }

    await _ensureLoaded();

    final topMatches = _findTopMatches(userInput: userInput, limit: 5);
    final sourceTitles = topMatches
        .map((item) => item.title)
        .where((title) => title.trim().isNotEmpty)
        .toSet()
        .toList();

    final apiKey = _config?.geminiApiKey.trim() ?? '';
    if (apiKey.isEmpty) {
      return _buildDatasetOnlyReply(
        userInput: userInput,
        topMatches: topMatches,
        sourceTitles: sourceTitles,
      );
    }

    try {
      final model = GenerativeModel(
        model: _config?.geminiModel ?? 'gemini-1.5-flash-latest',
        apiKey: apiKey,
      );

      final response = await model.generateContent([
        Content.text(
          _buildPrompt(
            userInput: userInput,
            history: history,
            topMatches: topMatches,
          ),
        ),
      ]);

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return _buildDatasetOnlyReply(
          userInput: userInput,
          topMatches: topMatches,
          sourceTitles: sourceTitles,
          prefix:
              'I could not get a model response right now, so here is guidance from your Firebase legal dataset.',
        );
      }

      return LegalAiReply(text: text, sourceTitles: sourceTitles);
    } catch (_) {
      return _buildDatasetOnlyReply(
        userInput: userInput,
        topMatches: topMatches,
        sourceTitles: sourceTitles,
        prefix:
            'Gemini is unavailable right now, so here is guidance from your Firebase legal dataset.',
      );
    }
  }

  Future<void> _ensureLoaded() async {
    final now = DateTime.now();
    if (_lastLoadedAt != null && now.difference(_lastLoadedAt!).inMinutes < 3) {
      return;
    }

    final configDoc = await _firestore
        .collection('legal_ai_config')
        .doc('default')
        .get();

    _config = _LegalAiConfig.fromMap(configDoc.data() ?? const {});

    final datasetCollection = _config?.datasetCollection ?? 'legal_ai_dataset';
    final maxDocs = _config?.maxDatasetDocs ?? 300;

    final datasetSnapshot = await _firestore
        .collection(datasetCollection)
        .limit(maxDocs)
        .get();

    _dataset = datasetSnapshot.docs
        .map((doc) => _LegalDatasetItem.fromMap(id: doc.id, map: doc.data()))
        .where((item) => item.content.trim().isNotEmpty)
        .toList();

    _lastLoadedAt = now;
  }

  LegalAiReply _buildDatasetOnlyReply({
    required String userInput,
    required List<_LegalDatasetItem> topMatches,
    required List<String> sourceTitles,
    String? prefix,
  }) {
    if (topMatches.isEmpty) {
      return LegalAiReply(
        text:
            '${prefix == null ? '' : '$prefix\n\n'}I could not find a direct answer in your Firebase legal dataset. Please upload more legal documents or include a clearer legal topic and jurisdiction in your question.',
      );
    }

    final best = topMatches.first;
    final excerpt = _truncate(best.content.replaceAll('\n', ' ').trim(), 650);

    final responseText = StringBuffer();
    if (prefix != null && prefix.trim().isNotEmpty) {
      responseText.writeln(prefix);
      responseText.writeln();
    }
    responseText.writeln('Here is what your legal dataset suggests:');
    responseText.writeln(excerpt);
    responseText.writeln();
    responseText.writeln(
      'If you want a deeper answer like ChatGPT/Gemini, add `geminiApiKey` inside Firestore at legal_ai_config/default.',
    );

    return LegalAiReply(
      text: responseText.toString().trim(),
      sourceTitles: sourceTitles,
    );
  }

  String _buildPrompt({
    required String userInput,
    required List<LegalAiHistoryMessage> history,
    required List<_LegalDatasetItem> topMatches,
  }) {
    final prompt = StringBuffer()
      ..writeln(
        'You are Mezaan Legal AI. You must answer only legal questions and refuse any non-legal request.',
      )
      ..writeln(
        'You MUST reply in the exact same language the user uses (if they type in Arabic, reply in Arabic. If English, reply in English).',
      )
      ..writeln(
        'Important: This assistant gives general legal information only, not a substitute for a licensed lawyer.',
      )
      ..writeln(
        'You MUST base your answers strictly on the "Relevant legal dataset context" provided below. Do not contradict the dataset.',
      )
      ..writeln(
        'If the user asks non-legal content, answer exactly: I can only help with legal topics.',
      )
      ..writeln()
      ..writeln('Recent chat history:');

    final recentHistory = history.length > 8
        ? history.sublist(history.length - 8)
        : history;

    for (final item in recentHistory) {
      prompt.writeln('${item.role.name.toUpperCase()}: ${item.text}');
    }

    prompt.writeln();
    prompt.writeln('Relevant legal dataset context from Firebase:');

    if (topMatches.isEmpty) {
      prompt.writeln('- No matching dataset entries found.');
    } else {
      for (var i = 0; i < topMatches.length; i++) {
        final item = topMatches[i];
        prompt.writeln(
          '${i + 1}. Title: ${item.title.isEmpty ? 'Untitled' : item.title}',
        );
        if (item.tags.isNotEmpty) {
          prompt.writeln('Tags: ${item.tags.join(', ')}');
        }
        prompt.writeln('Content: ${_truncate(item.content, 1200)}');
        prompt.writeln();
      }
    }

    prompt.writeln('User question: $userInput');
    prompt.writeln();
    prompt.writeln('Response style requirements:');
    prompt.writeln('- Keep answer concise and actionable.');
    prompt.writeln('- Include 3-6 clear legal steps when possible.');
    prompt.writeln('- Mention missing facts if needed for legal accuracy.');
    prompt.writeln('- Do not invent laws or citations.');

    return prompt.toString();
  }

  List<_LegalDatasetItem> _findTopMatches({
    required String userInput,
    int limit = 5,
  }) {
    if (_dataset.isEmpty) {
      return const [];
    }

    final queryTokens = _tokenize(userInput);
    if (queryTokens.isEmpty) {
      return _dataset.take(limit).toList();
    }

    final scored = <({double score, _LegalDatasetItem item})>[];

    for (final item in _dataset) {
      final haystack = [
        item.title,
        item.content,
        item.tags.join(' '),
      ].join(' ');
      final normalizedHaystack = _normalize(haystack);
      var score = 0.0;

      for (final token in queryTokens) {
        if (token.isEmpty) {
          continue;
        }

        if (normalizedHaystack.contains(token)) {
          score += 1.5;
        }

        if (_normalize(item.title).contains(token)) {
          score += 2.2;
        }

        if (item.tags.any((tag) => _normalize(tag).contains(token))) {
          score += 2.8;
        }
      }

      if (score > 0) {
        score += min(item.content.length / 1000.0, 1.2);
        scored.add((score: score, item: item));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) {
      return _dataset.take(limit).toList();
    }

    return scored.take(limit).map((entry) => entry.item).toList();
  }

  bool _isLegalQuestion(String input) {
    final text = _normalize(input);
    if (text.isEmpty) {
      return false;
    }

    const legalHints = [
      'law',
      'legal',
      'court',
      'judge',
      'lawsuit',
      'case',
      'rights',
      'contract',
      'agreement',
      'divorce',
      'custody',
      'inheritance',
      'property',
      'tenant',
      'landlord',
      'criminal',
      'civil',
      'evidence',
      'complaint',
      'attorney',
      'lawyer',
      'procedure',
      'appeal',
      'bail',
      'labor',
      'employment',
      'visa',
      'immigration',
      'police',
      'حقوق',
      'قانون',
      'محكمة',
      'قضية',
      'عقد',
      'طلاق',
      'نفقة',
      'حضانة',
      'ميراث',
      'ملكية',
      'ايجار',
      'إيجار',
      'شرطه',
      'شرطة',
      'جناية',
      'جنحة',
      'استئناف',
      'محامي',
      'اثبات',
      'إثبات',
    ];

    return legalHints.any(text.contains);
  }

  List<String> _tokenize(String input) {
    final normalized = _normalize(input);
    final parts = normalized
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((part) => part.trim().length > 2)
        .toList();
    return parts;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim();
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }
}

class LegalAiReply {
  final String text;
  final List<String> sourceTitles;

  const LegalAiReply({required this.text, this.sourceTitles = const []});
}

class LegalAiHistoryMessage {
  final LegalAiRole role;
  final String text;

  const LegalAiHistoryMessage({required this.role, required this.text});
}

enum LegalAiRole { user, assistant }

class _LegalAiConfig {
  final String geminiApiKey;
  final String geminiModel;
  final String datasetCollection;
  final int maxDatasetDocs;

  const _LegalAiConfig({
    required this.geminiApiKey,
    required this.geminiModel,
    required this.datasetCollection,
    required this.maxDatasetDocs,
  });

  factory _LegalAiConfig.fromMap(Map<String, dynamic> map) {
    final configuredLimit = map['maxDatasetDocs'];
    var parsedLimit = 300;
    if (configuredLimit is int) {
      parsedLimit = configuredLimit;
    } else if (configuredLimit is String) {
      parsedLimit = int.tryParse(configuredLimit) ?? 300;
    }

    return _LegalAiConfig(
      geminiApiKey: map['geminiApiKey']?.toString() ?? '',
      geminiModel: map['geminiModel']?.toString().trim().isNotEmpty == true
          ? map['geminiModel'].toString().trim()
          : 'gemini-1.5-flash-latest',
      datasetCollection:
          map['datasetCollection']?.toString().trim().isNotEmpty == true
          ? map['datasetCollection'].toString().trim()
          : 'legal_ai_dataset',
      maxDatasetDocs: parsedLimit.clamp(50, 1500),
    );
  }
}

class _LegalDatasetItem {
  final String id;
  final String title;
  final String content;
  final List<String> tags;

  const _LegalDatasetItem({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
  });

  factory _LegalDatasetItem.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final dynamicTags = map['tags'];
    List<String> tags = const [];

    if (dynamicTags is List) {
      tags = dynamicTags.map((item) => item.toString()).toList();
    } else if (dynamicTags is String && dynamicTags.trim().isNotEmpty) {
      tags = dynamicTags
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return _LegalDatasetItem(
      id: id,
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      tags: tags,
    );
  }
}
