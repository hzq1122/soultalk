import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/api_config.dart';
import '../../models/message.dart';
import 'llm_service.dart';

class AnthropicAdapterImpl implements LlmService {
  static const String _defaultBaseUrl = 'https://api.anthropic.com';
  static const String _anthropicVersion = '2023-06-01';

  /// 可注入的 Dio（测试时替换 HttpClientAdapter 捕获请求体）；
  /// 流式请求使用独立实例以避免干扰非流式连接池。
  final Dio _dio;

  AnthropicAdapterImpl({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 120),
            ),
          );

  String _normalizeUrl(String url) {
    final base = url.isNotEmpty ? url : _defaultBaseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  /// 将 reasoningEffort 配置解析为 Anthropic 官方 thinking.budget_tokens。
  /// 支持数值字符串（如 "8192"）或 low/medium/high 映射，默认 8192。
  /// Anthropic 要求 max_tokens 必须大于 budget_tokens，因此钳制为
  /// min(映射值, maxTokens - 1)，保证请求参数合法。
  static int _budgetTokens(String effort, int maxTokens) {
    int mapped;
    final parsed = int.tryParse(effort.trim());
    if (parsed != null && parsed > 0) {
      mapped = parsed;
    } else {
      mapped = switch (effort.trim().toLowerCase()) {
        'low' => 1024,
        'medium' => 4096,
        'high' => 8192,
        _ => 8192,
      };
    }
    if (maxTokens <= 1) return mapped;
    return mapped < maxTokens ? mapped : maxTokens - 1;
  }

  Map<String, String> _headers(ApiConfig config) => {
    'x-api-key': config.apiKey,
    'anthropic-version': _anthropicVersion,
    'Content-Type': 'application/json',
  };

  /// Anthropic API 不允许 messages 中出现 system 角色：
  /// 过滤 system 消息（由顶层 system 字段承载，见 [LlmService.extractSystemPrompt]）。
  List<Map<String, String>> _buildMessages(List<Message> messages) {
    return LlmService.toApiMessages(
      messages,
    ).where((m) => m['role'] != 'system').toList();
  }

  /// 拼接顶层 system：参数 systemPrompt 在前，messages 内嵌的 system
  /// 消息（post_history_instructions 等）在后，保证顺序语义。
  static String _mergeSystemPrompt(
    String? systemPrompt,
    List<Message> messages,
  ) {
    final parts = [
      if (systemPrompt != null && systemPrompt.isNotEmpty) systemPrompt,
      LlmService.extractSystemPrompt(messages),
    ].where((s) => s.isNotEmpty);
    return parts.join('\n\n');
  }

  @override
  Future<String> sendMessage({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = _normalizeUrl(config.baseUrl);
    final body = <String, dynamic>{
      'model': config.model,
      'max_tokens': config.maxTokens,
      'messages': _buildMessages(messages),
    };
    final mergedSystem = _mergeSystemPrompt(systemPrompt, messages);
    if (mergedSystem.isNotEmpty) {
      body['system'] = mergedSystem;
    }
    if (config.thinkingEnabled) {
      // Anthropic 官方思考参数：thinking.type + budget_tokens
      body['thinking'] = {
        'type': 'enabled',
        'budget_tokens': _budgetTokens(
          config.reasoningEffort,
          config.maxTokens,
        ),
      };
    }

    final response = await _dio.post(
      '$baseUrl/v1/messages',
      data: body,
      options: Options(headers: _headers(config)),
      cancelToken: cancelToken,
    );
    final data = response.data as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) {
      throw Exception('API 返回了空的 content');
    }
    // 思考模式下 thinking block 在前：遍历所有 block，拼接 text 块
    // （text 可能是字符串或 {type: 'text', text: ...} 对象）。
    final textParts = <String>[];
    for (final block in content) {
      if (block is! Map) continue;
      final blockMap = block as Map<String, dynamic>;
      final text = blockMap['text'];
      if (text is String && text.isNotEmpty) {
        textParts.add(text);
      }
    }
    return textParts.join();
  }

  @override
  Stream<String> sendMessageStream({
    required ApiConfig config,
    required List<Message> messages,
    String? systemPrompt,
    CancelToken? cancelToken,
  }) async* {
    final baseUrl = _normalizeUrl(config.baseUrl);
    final streamDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    final body = <String, dynamic>{
      'model': config.model,
      'max_tokens': config.maxTokens,
      'messages': _buildMessages(messages),
      'stream': true,
    };
    final mergedSystem = _mergeSystemPrompt(systemPrompt, messages);
    if (mergedSystem.isNotEmpty) {
      body['system'] = mergedSystem;
    }
    if (config.thinkingEnabled) {
      // Anthropic 官方思考参数：thinking.type + budget_tokens
      body['thinking'] = {
        'type': 'enabled',
        'budget_tokens': _budgetTokens(
          config.reasoningEffort,
          config.maxTokens,
        ),
      };
    }

    final response = await streamDio.post<ResponseBody>(
      '$baseUrl/v1/messages',
      data: body,
      options: Options(
        headers: _headers(config),
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
    );

    if (response.data == null) {
      throw Exception('API 流式响应为空');
    }

    final lineBuffer = StringBuffer();
    // utf8.decoder.bind 内部会缓冲跨 chunk 的不完整多字节字符，
    // 避免对每个网络 chunk 单独解码产生 U+FFFD 乱码。
    await for (final text in utf8.decoder.bind(response.data!.stream)) {
      lineBuffer.write(text);

      final raw = lineBuffer.toString();
      final lastNl = raw.lastIndexOf('\n');
      if (lastNl < 0) continue;

      final completeLines = raw.substring(0, lastNl + 1);
      lineBuffer.clear();
      lineBuffer.write(raw.substring(lastNl + 1));

      for (final line in completeLines.split('\n')) {
        final trimmed = line.trim();
        // 兼容 'data: {...}' 与 'data:{...}' 两种前缀
        if (!trimmed.startsWith('data:')) continue;
        final jsonStr = trimmed.substring(5).trim();
        if (jsonStr == '[DONE]') return;
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = json['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = json['delta'] as Map<String, dynamic>?;
            final text = delta?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
            }
            // 思考模式：thinking_delta 块（官方字段 thinking，
            // 部分兼容端点使用 thinking_delta）
            final thinkingRaw = delta?['thinking'] ?? delta?['thinking_delta'];
            final thinking = thinkingRaw as String?;
            if (thinking != null && thinking.isNotEmpty) {
              yield '\x00__R__\x00$thinking';
            }
          }
        } catch (_) {}
      }
    }
  }
}
