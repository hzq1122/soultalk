import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/memory_state.dart';
import 'package:soultalk/platform/platform_config_stub.dart';
import 'package:soultalk/services/memory/state_renderer.dart';

void main() {
  group('StateRenderer', () {
    late StateRenderer renderer;

    setUp(() {
      renderer = StateRenderer(const StubPlatformConfig());
    });

    test('returns empty for no states', () {
      expect(renderer.render([]), '');
    });

    test('returns empty for empty state values', () {
      final states = [
        MemoryState(
          id: 's1',
          contactId: 'c1',
          slotName: 'mood',
          slotValue: '',
          updatedAt: DateTime.now(),
        ),
      ];

      expect(renderer.render(states), '');
    });

    test('renders active states', () {
      final states = [
        MemoryState(
          id: 's1',
          contactId: 'c1',
          slotName: 'mood',
          slotValue: 'happy',
          updatedAt: DateTime.now(),
        ),
        MemoryState(
          id: 's2',
          contactId: 'c1',
          slotName: 'topic',
          slotValue: 'AI safety',
          updatedAt: DateTime.now(),
        ),
      ];

      final text = renderer.render(states);

      expect(text, contains('[当前状态]'));
      expect(text, contains('mood'));
      expect(text, contains('happy'));
      expect(text, contains('topic'));
      expect(text, contains('AI safety'));
    });

    test('skips stale states', () {
      final states = [
        MemoryState(
          id: 's1',
          contactId: 'c1',
          slotName: 'active_slot',
          slotValue: 'value',
          status: 'active',
          updatedAt: DateTime.now(),
        ),
        MemoryState(
          id: 's2',
          contactId: 'c1',
          slotName: 'stale_slot',
          slotValue: 'old value',
          status: 'stale',
          updatedAt: DateTime.now(),
        ),
      ];

      final text = renderer.render(states);

      expect(text, contains('active_slot'));
      expect(text, isNot(contains('stale_slot')));
    });

    test('skips empty value states', () {
      final states = [
        MemoryState(
          id: 's1',
          contactId: 'c1',
          slotName: 'filled',
          slotValue: 'has value',
          updatedAt: DateTime.now(),
        ),
        MemoryState(
          id: 's2',
          contactId: 'c1',
          slotName: 'empty',
          slotValue: '   ',
          updatedAt: DateTime.now(),
        ),
      ];

      final text = renderer.render(states);

      expect(text, contains('filled'));
      expect(text, isNot(contains('empty')));
    });
  });
}
