import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/proactive/rule_guards.dart';

void main() {
  group('isInQuietHours', () {
    test('normal range within and outside', () {
      final within = DateTime(2026, 1, 1, 12);
      expect(isInQuietHours(within, 10, 14), isTrue);
      final outside = DateTime(2026, 1, 1, 15);
      expect(isInQuietHours(outside, 10, 14), isFalse);
    });

    test('cross-midnight range 23->7', () {
      expect(isInQuietHours(DateTime(2026, 1, 1, 23), 23, 7), isTrue);
      expect(isInQuietHours(DateTime(2026, 1, 1, 3), 23, 7), isTrue);
      expect(isInQuietHours(DateTime(2026, 1, 1, 6, 59), 23, 7), isTrue);
      expect(isInQuietHours(DateTime(2026, 1, 1, 7), 23, 7), isFalse);
      expect(isInQuietHours(DateTime(2026, 1, 1, 12), 23, 7), isFalse);
    });

    test('equal hours means no quiet period', () {
      expect(isInQuietHours(DateTime(2026, 1, 1, 5), 23, 23), isFalse);
      expect(isInQuietHours(DateTime(2026, 1, 1, 23), 23, 23), isFalse);
    });
  });
}
