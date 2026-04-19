import 'dart:async';
import 'dart:math';

class TypingSimulator {
  static final _random = Random();

  static Duration calculateDelay(String userMessage) {
    final baseMs = 800 + _random.nextInt(2200);
    final lengthFactor = (userMessage.length / 20).clamp(0.5, 2.0);
    return Duration(milliseconds: (baseMs * lengthFactor).toInt());
  }

  static Future<void> simulateDelay(String userMessage) async {
    await Future.delayed(calculateDelay(userMessage));
  }
}
