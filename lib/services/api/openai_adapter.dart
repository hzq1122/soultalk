import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/api_config.dart';
import '../../models/message.dart';
import 'llm_service.dart';

/// OpenAI 兼容协议 Adapter（支持 OpenAI、Claude via OpenAI compat、本地模型等）
class OpenAiAdapterImpl implements LlmService {
  Dio get _dio => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ));

  List<Map<String, String>> _buildMessages(
      List<Message> messages, String? systemPrompt) {
    final result = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      result.add({'role': 'system', 'content': systemPrompt});
    }
    result.addAll(messagesToApiFormat(messages));
    return result;
  }

  @override
  Future<String> sendMessage({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  }) async {
    final baseUrl = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _dio.post(
      '$baseUrl/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': config.model,
        'messages': _buildMessages(messages, systemPrompt),
        'max_tokens': config.maxTokens,
        'temperature': config.temperature,
        'stream': false,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['choices'] as List).first['message']['content'] as String;
  }

  @override
  Stream<String> sendMessageStream({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
  }) async* {
    final baseUrl = _normalizeUrl(config.baseUrl);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));

    final response = await dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': config.model,
        'messages': _buildMessages(messages, systemPrompt),
        'max_tokens': config.maxTokens,
        'temperature': config.temperature,
        'stream': true,
      },
    );

    // 行缓冲区：SSE 行可能被网络层截断到多个 chunk
    final lineBuffer = StringBuffer();
    await for (final chunk in response.data!.stream) {
      lineBuffer.write(utf8.decode(chunk));

      // 只处理以 \n 结尾的完整行，剩余部分留在缓冲区
      final raw = lineBuffer.toString();
      final lastNl = raw.lastIndexOf('\n');
      if (lastNl < 0) continue;

      final completeLines = raw.substring(0, lastNl + 1);
      lineBuffer.clear();
      lineBuffer.write(raw.substring(lastNl + 1));

      for (final line in completeLines.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final jsonStr = trimmed.substring(6).trim();
        if (jsonStr == '[DONE]') return;
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta =
                choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {}
      }
    }
  }

  /// 去除末尾多余的斜杠，避免拼出 /v1//chat/completions
  String _normalizeUrl(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  List<Map<String, String>> messagesToApiFormat(List<Message> messages) {
    return messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();
  }
}
