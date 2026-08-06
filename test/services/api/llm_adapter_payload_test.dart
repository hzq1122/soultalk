import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soultalk/models/api_config.dart';
import 'package:soultalk/models/message.dart';
import 'package:soultalk/services/api/anthropic_adapter.dart';
import 'package:soultalk/services/api/llm_service.dart';
import 'package:soultalk/services/api/openai_adapter.dart';

/// 捕获请求的 mock HttpClientAdapter：记录 uri 与请求体，
/// 返回固定的 OpenAI/Anthropic 格式响应。
class _CaptureAdapter implements HttpClientAdapter {
  final List<({Uri uri, Object? body, Map<String, dynamic> headers})> requests =
      [];

  final bool anthropic;

  _CaptureAdapter({this.anthropic = false});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      uri: options.uri,
      body: options.data,
      headers: options.headers,
    ));
    if (anthropic) {
      return ResponseBody.fromString(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'ok'},
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'ok'},
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _decodeBody(Object? body) => body is String
    ? jsonDecode(body) as Map<String, dynamic>
    : (body as Map<String, dynamic>);

ApiConfig _config(LlmProvider provider) => ApiConfig(
  id: 'cfg_1',
  name: 'test',
  provider: provider,
  baseUrl: 'https://api.example.com',
  apiKey: 'sk-test',
  model: 'test-model',
  maxTokens: 512,
  temperature: 0.7,
  streamEnabled: false,
);

List<Message> _history() => [
  Message(id: 'u1', contactId: 'c1', role: MessageRole.user, content: '你好'),
  Message(
    id: 'a1',
    contactId: 'c1',
    role: MessageRole.assistant,
    content: '你好！',
  ),
];

/// ST 语义：post_history_instructions 作为最后一条 system 消息。
Message _postHistoryInstruction() => Message(
  id: '',
  contactId: 'c1',
  role: MessageRole.system,
  content: 'post history instruction',
);

void main() {
  group('OpenAI 兼容端点 payload', () {
    test('systemPrompt 在最前，post_history_instructions 在历史之后', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = OpenAiAdapterImpl(dio: dio);

      final result = await service.sendMessage(
        config: _config(LlmProvider.openai),
        messages: [..._history(), _postHistoryInstruction()],
        systemPrompt: 'base system prompt',
      );

      expect(result, 'ok');
      expect(adapter.requests, hasLength(1));
      final data = _decodeBody(adapter.requests.single.body);
      final messages = data['messages'] as List<dynamic>;

      expect(messages, hasLength(4));
      expect(messages[0], {'role': 'system', 'content': 'base system prompt'});
      expect(messages[1], {'role': 'user', 'content': '你好'});
      expect(messages[2], {'role': 'assistant', 'content': '你好！'});
      // 关键断言：post_history_instructions 不再被过滤
      expect(messages[3], {
        'role': 'system',
        'content': 'post history instruction',
      });
      expect(data['stream'], false);
      expect(data['model'], 'test-model');
    });

    test('无 system 消息时请求体只有历史', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = OpenAiAdapterImpl(dio: dio);

      await service.sendMessage(
        config: _config(LlmProvider.custom),
        messages: _history(),
      );

      final messages =
          _decodeBody(adapter.requests.single.body)['messages'] as List;
      expect(messages, hasLength(2));
      expect(
        messages.map((m) => (m as Map)['role']),
        isNot(contains('system')),
      );
    });
  });

  group('Anthropic 端点 payload', () {
    test('system 角色并入顶层 system，messages 不含 system', () async {
      final adapter = _CaptureAdapter(anthropic: true);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = AnthropicAdapterImpl(dio: dio);

      final result = await service.sendMessage(
        config: _config(LlmProvider.anthropic),
        messages: [..._history(), _postHistoryInstruction()],
        systemPrompt: 'base system prompt',
      );

      expect(result, 'ok');
      final data = _decodeBody(adapter.requests.single.body);
      // 顶层 system：基础 prompt + post_history_instructions
      expect(data['system'], contains('base system prompt'));
      expect(data['system'], contains('post history instruction'));
      expect(data['system'], endsWith('post history instruction'));

      final messages = data['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      for (final m in messages) {
        expect((m as Map)['role'], isNot('system'));
      }
    });

    test('无 system 消息时不带 system 字段', () async {
      final adapter = _CaptureAdapter(anthropic: true);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = AnthropicAdapterImpl(dio: dio);

      await service.sendMessage(
        config: _config(LlmProvider.anthropic),
        messages: _history(),
      );

      final data = _decodeBody(adapter.requests.single.body);
      expect(data.containsKey('system'), isFalse);
    });
  });

  group('LlmService.toApiMessages', () {
    test('保留 system 角色并正确映射 role', () {
      final api = LlmService.toApiMessages([
        ..._history(),
        _postHistoryInstruction(),
      ]);
      expect(api, [
        {'role': 'user', 'content': '你好'},
        {'role': 'assistant', 'content': '你好！'},
        {'role': 'system', 'content': 'post history instruction'},
      ]);
    });

    test('extractSystemPrompt 按顺序拼接并忽略空内容', () {
      expect(
        LlmService.extractSystemPrompt([
          Message(
            id: '',
            contactId: 'c1',
            role: MessageRole.system,
            content: '   ',
          ),
          _postHistoryInstruction(),
        ]),
        'post history instruction',
      );
      expect(LlmService.extractSystemPrompt(_history()), isEmpty);
    });
  });
}
