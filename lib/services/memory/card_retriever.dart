import 'package:soultalk/platform/platform_config.dart';
import '../../models/memory_card.dart';
import '../database/memory_card_dao.dart';

/// Retrieves memory cards via keyword matching with multi-factor scoring.
class CardRetriever {
  final MemoryCardDao _dao;
  final PlatformConfig _config;

  CardRetriever(this._dao, [PlatformConfig? config])
      : _config = config ?? PlatformConfig.current;

  /// Score and return the top-K memory cards for [contactId] matching [keywords].
  ///
  /// Scoring weights: importance 45%, confidence 25%, recency 20%, scope 10%.
  Future<List<MemoryCard>> retrieve(String contactId, List<String> keywords) async {
    if (keywords.isEmpty) return [];

    final candidates = await _dao.searchByKeywords(contactId, keywords);
    if (candidates.isEmpty) return [];

    final now = DateTime.now();
    final scored = candidates.map((card) {
      final ageDays = now.difference(card.createdAt).inDays.clamp(0, 365).toDouble();
      final recency = 1.0 - (ageDays / 365);
      final scopeWeight = card.scope == 'global' ? 1.0 : card.scope == 'shared' ? 0.7 : 0.4;
      final score = card.importance * 0.45 +
          card.confidence * 0.25 +
          recency * 0.20 +
          scopeWeight * 0.10;
      return _ScoredCard(card, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(_config.retrievalTopK).map((s) => s.card).toList();
  }
}

class _ScoredCard {
  final MemoryCard card;
  final double score;
  const _ScoredCard(this.card, this.score);
}
