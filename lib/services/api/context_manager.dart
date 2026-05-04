import '../../models/message.dart';
import '../../models/api_config.dart';

enum ContextStrategy {
  slidingWindow, // 保留最近 N 条消息
  tokenBudget, // 按 Token 预算裁剪
}

/// 上下文窗口管理器
class ContextManager {
  final ContextStrategy strategy;
  final int maxMessages; // 滑动窗口大小（对话轮次）
  final int maxTokenBudget; // Token 预算上限

  const ContextManager({
    this.strategy = ContextStrategy.slidingWindow,
    this.maxMessages = 20,
    this.maxTokenBudget = 3000,
  });

  /// 根据策略裁剪消息列表
  List<Message> trim(List<Message> messages, ApiConfig config) {
    if (messages.isEmpty) return messages;

    switch (strategy) {
      case ContextStrategy.slidingWindow:
        return _slidingWindow(messages);
      case ContextStrategy.tokenBudget:
        return _tokenBudget(messages, config.maxTokens);
    }
  }

  List<Message> _slidingWindow(List<Message> messages) {
    // 保留最近 maxMessages 条（不含 system 消息）
    final nonSystem = messages
        .where((m) => m.role != MessageRole.system)
        .toList();
    if (nonSystem.length <= maxMessages) return messages;

    final kept = nonSystem.sublist(nonSystem.length - maxMessages);
    return kept;
  }

  List<Message> _tokenBudget(List<Message> messages, int configMaxTokens) {
    // 估算 token 数（简单估算：4字符≈1token，中文2字符≈1token）
    final budget = (configMaxTokens * 0.6).toInt().clamp(500, maxTokenBudget);

    int totalTokens = 0;
    final result = <Message>[];

    // 从后往前累加，直到超出预算
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role == MessageRole.system) continue;
      final estimated = _estimateTokens(msg.content);
      if (totalTokens + estimated > budget && result.isNotEmpty) break;
      totalTokens += estimated;
      result.insert(0, msg);
    }

    return result;
  }

  int _estimateTokens(String text) {
    // 粗略估算：中文每字约1token，ASCII 4字符约1token
    int count = 0;
    for (final char in text.runes) {
      count += char > 0x7F ? 4 : 1; // 中文字符×4，ASCII字符×1，最终除以4
    }
    return (count ~/ 4).clamp(1, 999999);
  }
}
