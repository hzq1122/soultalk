import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/memory_card.dart';
import 'package:soultalk/services/memory/review_policy.dart';

void main() {
  group('ReviewPolicy', () {
    late ReviewPolicy policy;

    setUp(() {
      policy = ReviewPolicy();
    });

    test('rejects low importance cards', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Some trivia',
        importance: 0.2,
        confidence: 0.9,
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.reject);
    });

    test('rejects suggested_action:reject tag', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Bad info',
        importance: 0.8,
        confidence: 0.9,
        tags: ['suggested_action:reject'],
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.reject);
    });

    test('approves high quality cards', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'User prefers dark mode',
        cardType: 'preference',
        importance: 0.8,
        confidence: 0.9,
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.approve);
    });

    test('pending for boundary type cards', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'User does not like personal questions',
        cardType: 'boundary',
        importance: 0.8,
        confidence: 0.9,
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.pending);
    });

    test('pending for relationship type cards', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'User is close friends with Bob',
        cardType: 'relationship',
        importance: 0.8,
        confidence: 0.9,
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.pending);
    });

    test('pending for low confidence cards', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Maybe user likes pizza?',
        importance: 0.5,
        confidence: 0.4,
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.pending);
    });

    test('approves low risk fact cards', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'User was born in Beijing',
        cardType: 'fact',
        importance: 0.75,
        confidence: 0.9,
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.approve);
    });

    test('pending for suggested_action:pending tag', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Needs review',
        importance: 0.8,
        confidence: 0.9,
        tags: ['suggested_action:pending'],
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.pending);
    });

    test('approves with suggested_action:auto_approve tag', () {
      final card = MemoryCard(
        id: 'c1',
        contactId: 'ct1',
        content: 'Auto approved content',
        importance: 0.75,
        confidence: 0.9,
        tags: ['suggested_action:auto_approve'],
        createdAt: DateTime.now(),
      );

      expect(policy.review(card), ReviewAction.approve);
    });
  });
}
