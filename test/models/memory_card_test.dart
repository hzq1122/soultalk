import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/memory_card.dart';

void main() {
  group('MemoryCard', () {
    test('fromDbMap handles null fields gracefully', () {
      final map = <String, dynamic>{};
      final card = MemoryCard.fromDbMap(map);

      expect(card.id, '');
      expect(card.contactId, '');
      expect(card.content, '');
      expect(card.cardType, 'fact');
      expect(card.importance, 0.5);
      expect(card.confidence, 0.5);
      expect(card.scope, 'local');
      expect(card.tags, isEmpty);
      expect(card.status, 'active');
    });

    test('fromDbMap parses valid data', () {
      final map = {
        'id': 'c1',
        'contact_id': 'ct1',
        'content': 'User likes coffee',
        'card_type': 'preference',
        'importance': 0.85,
        'confidence': 0.9,
        'scope': 'shared',
        'tags': 'food,drink',
        'status': 'active',
        'created_at': '2024-06-01T12:00:00.000',
        'reviewed_at': '2024-06-02T12:00:00.000',
      };

      final card = MemoryCard.fromDbMap(map);

      expect(card.id, 'c1');
      expect(card.content, 'User likes coffee');
      expect(card.cardType, 'preference');
      expect(card.importance, 0.85);
      expect(card.scope, 'shared');
      expect(card.tags, ['food', 'drink']);
      expect(card.status, 'active');
    });

    test('fromDbMap handles empty tags', () {
      final map = {
        'id': 'c1',
        'contact_id': 'ct1',
        'content': 'Test',
        'created_at': '2024-01-01T00:00:00.000',
      };

      final card = MemoryCard.fromDbMap(map);

      expect(card.tags, isEmpty);
    });

    test('toJson includes all fields', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Test',
        cardType: 'fact',
        importance: 0.7,
        confidence: 0.8,
        scope: 'local',
        tags: ['test'],
        createdAt: DateTime(2024),
      );

      final json = card.toJson();

      expect(json['id'], 'c1');
      expect(json['content'], 'Test');
      expect(json['importance'], 0.7);
      expect(json['tags'], ['test']);
    });

    test('copyWith preserves unchanged fields', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Original',
        createdAt: DateTime(2024),
      );

      final copied = card.copyWith(content: 'Updated', importance: 0.9);

      expect(copied.id, 'c1');
      expect(copied.content, 'Updated');
      expect(copied.importance, 0.9);
      expect(copied.status, 'active');
    });
  });
}
