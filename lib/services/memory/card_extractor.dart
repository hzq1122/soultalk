import 'package:uuid/uuid.dart';
import '../../models/memory_card.dart';

/// Extracts candidate memory cards from conversations.
///
/// Parses LLM output for memory extraction in the format:
/// [MEMORY:card_type] content (importance: 0.8, confidence: 0.9, scope: local, tags: tag1,tag2)
class CardExtractor {
  static const _uuid = Uuid();

  const CardExtractor();

  Future<List<MemoryCard>> extractFromResponse(
    String contactId,
    String aiResponse,
  ) async {
    final candidates = _parseCandidates(aiResponse);
    if (candidates.isEmpty) return [];

    final cards = <MemoryCard>[];
    for (final c in candidates) {
      final card = MemoryCard(
        id: _uuid.v4(),
        contactId: contactId,
        content: c.content,
        cardType: c.cardType,
        importance: c.importance,
        confidence: c.confidence,
        scope: c.scope,
        tags: c.tags,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      cards.add(card);
    }
    return cards;
  }

  List<_Candidate> _parseCandidates(String response) {
    final candidates = <_Candidate>[];
    final regex = RegExp(
      r'\[MEMORY:(\w+)\]\s*(.+?)\s*\(importance:\s*([\d.]+),\s*confidence:\s*([\d.]+)(?:,\s*scope:\s*(\w+))?(?:,\s*tags:\s*([^)]+))?\)',
      multiLine: true,
    );
    for (final match in regex.allMatches(response)) {
      final cardType = match.group(1) ?? 'fact';
      final content = (match.group(2) ?? '').trim();
      final importance = double.tryParse(match.group(3) ?? '') ?? 0.5;
      final confidence = double.tryParse(match.group(4) ?? '') ?? 0.5;
      final scope = match.group(5) ?? 'local';
      final tagsStr = match.group(6);
      final tags = tagsStr != null
          ? tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];
      if (content.isNotEmpty) {
        candidates.add(_Candidate(content, cardType, importance, confidence, scope, tags));
      }
    }
    return candidates;
  }
}

class _Candidate {
  final String content;
  final String cardType;
  final double importance;
  final double confidence;
  final String scope;
  final List<String> tags;
  const _Candidate(this.content, this.cardType, this.importance, this.confidence, this.scope, this.tags);
}
