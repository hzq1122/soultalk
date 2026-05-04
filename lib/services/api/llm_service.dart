import '../../models/api_config.dart';
import '../../models/message.dart';
import 'openai_adapter.dart';
import 'anthropic_adapter.dart';

/// LLM 统一接口
abstract class LlmService {
  /// 发送消息（非流式）
  Future<String> sendMessage({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  });

  /// 发送消息（流式）
  Stream<String> sendMessageStream({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  });

  /// 工厂方法：根据 Provider 创建对应 Adapter
  factory LlmService.fromConfig(ApiConfig config) {
    switch (config.provider) {
      case LlmProvider.anthropic:
        return AnthropicAdapterImpl();
      case LlmProvider.openai:
      case LlmProvider.custom:
        return OpenAiAdapterImpl();
    }
  }

  /// 将 Message 列表转为 API 消息格式（工具方法）
  static List<Map<String, String>> toApiMessages(List<Message> messages) {
    return messages
        .where((m) => m.role != MessageRole.system)
        .map(
          (m) => {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
  }
}
