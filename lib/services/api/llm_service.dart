import 'package:dio/dio.dart';

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
    CancelToken? cancelToken,
  });

  /// 发送消息（流式）
  Stream<String> sendMessageStream({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
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

  /// 将 Message 列表转为 API 消息格式（工具方法）。
  ///
  /// ST 语义：system 角色消息（如 post_history_instructions）按原顺序
  /// 保留在消息列表中，OpenAI 兼容端点允许 messages 中的 system 角色；
  /// Anthropic 端点不允许，由 adapter 用 [extractSystemPrompt] 提取。
  static List<Map<String, String>> toApiMessages(List<Message> messages) {
    return messages
        .map(
          (m) => {
            'role': switch (m.role) {
              MessageRole.user => 'user',
              MessageRole.assistant => 'assistant',
              MessageRole.system => 'system',
            },
            'content': m.content,
          },
        )
        .toList();
  }

  /// 提取 messages 中 system 角色消息的文本（按原顺序以空行拼接），
  /// 供不支持 messages 内 system 角色的 API（如 Anthropic）并入顶层
  /// system 字段。没有 system 消息时返回空字符串。
  static String extractSystemPrompt(List<Message> messages) {
    return messages
        .where((m) => m.role == MessageRole.system)
        .map((m) => m.content)
        .where((c) => c.trim().isNotEmpty)
        .join('\n\n');
  }
}
