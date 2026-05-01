import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/memory_state.dart';

void main() {
  group('MemoryState', () {
    test('fromDbMap handles null fields gracefully', () {
      final map = <String, dynamic>{};
      final state = MemoryState.fromDbMap(map);

      expect(state.id, '');
      expect(state.contactId, '');
      expect(state.slotName, '');
      expect(state.slotValue, '');
      expect(state.slotType, 'text');
      expect(state.status, 'active');
      expect(state.confidence, 0.5);
    });

    test('fromDbMap parses valid data', () {
      final map = {
        'id': 's1',
        'contact_id': 'c1',
        'slot_name': 'mood',
        'slot_value': 'happy',
        'slot_type': 'text',
        'status': 'active',
        'confidence': 0.9,
        'updated_at': '2024-06-01T12:00:00.000',
      };

      final state = MemoryState.fromDbMap(map);

      expect(state.id, 's1');
      expect(state.slotName, 'mood');
      expect(state.slotValue, 'happy');
      expect(state.confidence, 0.9);
      expect(state.status, 'active');
    });

    test('toJson includes all fields', () {
      final state = MemoryState(
        id: 's1',
        contactId: 'c1',
        slotName: 'mood',
        slotValue: 'happy',
        slotType: 'enum',
        confidence: 0.85,
        status: 'active',
        updatedAt: DateTime(2024),
      );

      final json = state.toJson();

      expect(json['id'], 's1');
      expect(json['contact_id'], 'c1');
      expect(json['slot_name'], 'mood');
      expect(json['slot_value'], 'happy');
      expect(json['status'], 'active');
    });

    test('copyWith preserves unchanged fields', () {
      final state = MemoryState(
        id: 's1',
        contactId: 'c1',
        slotName: 'mood',
        slotValue: 'happy',
        updatedAt: DateTime(2024),
      );

      final copied = state.copyWith(slotValue: 'sad');

      expect(copied.id, 's1');
      expect(copied.slotName, 'mood');
      expect(copied.slotValue, 'sad');
    });
  });
}
