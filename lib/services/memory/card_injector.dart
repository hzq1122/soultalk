import '../../models/memory_card.dart';

/// Injects retrieved memory cards into the message list as a system message.
class CardInjector {
  const CardInjector();

  /// Render cards into a compact text block and inject into [messages],
  /// placing it after the last system message found.
  List<Map<String, dynamic>> inject(
    List<Map<String, dynamic>> messages,
    List<MemoryCard> cards,
  ) {
    final activeCards = cards.where((c) => c.status == 'active').toList();
    if (activeCards.isEmpty) return messages;

    final buffer = StringBuffer();
    buffer.writeln('[相关记忆]');

    for (final card in activeCards) {
      final tagSuffix = card.tags.isNotEmpty ? ' [${card.tags.join(', ')}]' : '';
      buffer.writeln('- ${card.content}$tagSuffix');
    }

    final result = List<Map<String, dynamic>>.from(messages);
    var insertIdx = 0;
    for (var i = 0; i < result.length; i++) {
      if (result[i]['role'] == 'system') {
        insertIdx = i + 1;
        break;
      }
    }
    result.insert(insertIdx, {'role': 'system', 'content': buffer.toString().trim()});
    return result;
  }
}
