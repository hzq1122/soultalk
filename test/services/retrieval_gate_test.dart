import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/memory_state.dart';
import 'package:soultalk/services/memory/retrieval_gate.dart';

void main() {
  group('RetrievalGate', () {
    late RetrievalGate gate;

    setUp(() {
      gate = RetrievalGate(triggerKeywords: ['help', 'urgent']);
    });

    test('mode always returns true', () {
      final decision = gate.decide(
        userText: 'hello',
        mode: 'always',
      );

      expect(decision.shouldRetrieve, isTrue);
      expect(decision.reason, 'mode_always');
    });

    test('mode never returns false', () {
      final decision = gate.decide(
        userText: 'hello',
        mode: 'never',
      );

      expect(decision.shouldRetrieve, isFalse);
      expect(decision.reason, 'mode_never');
    });

    test('new session triggers retrieval', () {
      final decision = gate.decide(
        userText: 'hello world',
        turnIndex: null,
      );

      expect(decision.shouldRetrieve, isTrue);
      expect(decision.reasons, contains('new_session'));
    });

    test('turn 0 triggers retrieval as new session', () {
      final decision = gate.decide(
        userText: 'hello world',
        turnIndex: 0,
      );

      expect(decision.shouldRetrieve, isTrue);
    });

    test('keyword triggers retrieval', () {
      final decision = gate.decide(
        userText: 'I need help with something',
        turnIndex: 3,
      );

      expect(decision.shouldRetrieve, isTrue);
      expect(decision.reasons.any((r) => r.contains('keyword')), isTrue);
    });

    test('periodic retrieval every N turns', () {
      final decision = gate.decide(
        userText: 'hello world',
        turnIndex: 6,
      );

      expect(decision.shouldRetrieve, isTrue);
      expect(decision.reasons.any((r) => r.contains('periodic')), isTrue);
    });

    test('short text is skipped', () {
      final decision = gate.decide(
        userText: 'hi',
        turnIndex: 5,
      );

      expect(decision.shouldRetrieve, isFalse);
      expect(decision.reason, 'short_text');
    });

    test('state sufficient suppresses retrieval', () {
      final states = [
        MemoryState(
          id: 's1',
          contactId: 'c1',
          slotName: 'mood',
          slotValue: 'happy',
          confidence: 0.9,
          updatedAt: DateTime.now(),
        ),
        MemoryState(
          id: 's2',
          contactId: 'c1',
          slotName: 'topic',
          slotValue: 'coding',
          confidence: 0.9,
          updatedAt: DateTime.now(),
        ),
      ];

      final decision = gate.decide(
        userText: 'Tell me more',
        turnIndex: 3,
        stateItems: states,
      );

      expect(decision.shouldRetrieve, isFalse);
      expect(decision.reason, 'state_sufficient');
    });

    test('low state confidence triggers retrieval', () {
      final states = [
        MemoryState(
          id: 's1',
          contactId: 'c1',
          slotName: 'mood',
          slotValue: '?',
          confidence: 0.3,
          updatedAt: DateTime.now(),
        ),
      ];

      final decision = gate.decide(
        userText: 'What should we talk about?',
        turnIndex: 5,
        stateItems: states,
      );

      expect(decision.shouldRetrieve, isTrue);
      expect(decision.reasons, contains('low_state_confidence'));
    });

    test('calculates state statistics', () {
      final decision = gate.decide(
        userText: 'hello world',
        turnIndex: 3,
        stateItems: [],
      );

      expect(decision.stateItemCount, 0);
      expect(decision.avgStateConfidence, isNull);
    });
  });
}
