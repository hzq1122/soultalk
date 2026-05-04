/// MemoryCard — Warm layer: reviewed long-term memory card.
///
/// Cards carry importance/confidence scores and are retrieved via keyword
/// matching (RetrievalGate → CardRetriever pipeline). Scope and tags
/// replace jiyi1's memory_edges graph for initial simplicity.
class MemoryCard {
  final String id;
  final String contactId;
  final String content;
  final String
  cardType; // fact, event, preference, boundary, relationship, character_state, world_state, roleplay_rule, speech_style, misc
  final double importance; // 0.0-1.0
  final double confidence; // 0.0-1.0
  final String scope; // local, shared, global
  final List<String> tags;
  final String
  status; // active, archived, deprecated, superseded, pending, rejected
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const MemoryCard({
    required this.id,
    required this.contactId,
    required this.content,
    this.cardType = 'fact',
    this.importance = 0.5,
    this.confidence = 0.5,
    this.scope = 'local',
    this.tags = const [],
    this.status = 'active',
    required this.createdAt,
    this.reviewedAt,
  });

  MemoryCard copyWith({
    String? id,
    String? contactId,
    String? content,
    String? cardType,
    double? importance,
    double? confidence,
    String? scope,
    List<String>? tags,
    String? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
  }) {
    return MemoryCard(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      content: content ?? this.content,
      cardType: cardType ?? this.cardType,
      importance: importance ?? this.importance,
      confidence: confidence ?? this.confidence,
      scope: scope ?? this.scope,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toDbMap() => {
    'id': id,
    'contact_id': contactId,
    'content': content,
    'card_type': cardType,
    'importance': importance,
    'confidence': confidence,
    'scope': scope,
    'tags': tags.join(','),
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'reviewed_at': reviewedAt?.toIso8601String(),
  };

  factory MemoryCard.fromDbMap(Map<String, dynamic> map) {
    return MemoryCard(
      id: map['id'] as String? ?? '',
      contactId: map['contact_id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      cardType: map['card_type'] as String? ?? 'fact',
      importance: (map['importance'] as num?)?.toDouble() ?? 0.5,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      scope: map['scope'] as String? ?? 'local',
      tags: (map['tags'] as String? ?? '')
          .split(',')
          .where((t) => t.isNotEmpty)
          .toList(),
      status: map['status'] as String? ?? 'active',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      reviewedAt: DateTime.tryParse(map['reviewed_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'contact_id': contactId,
    'content': content,
    'card_type': cardType,
    'importance': importance,
    'confidence': confidence,
    'scope': scope,
    'tags': tags,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'reviewed_at': reviewedAt?.toIso8601String(),
  };
}
