import 'package:flutter_test/flutter_test.dart';

import 'package:soultalk_pc/api_config_manager.dart';

/// ApiConfig 容错解析测试：手机端 DTO（camelCase，无 apiKey）与
/// 旧协议（snake_case）都必须能解析，缺 apiKey 不得抛类型异常。
void main() {
  test('parses phone DTO (camelCase, no apiKey)', () {
    final config = ApiConfig.tryFromJson(const {
      'id': 'cfg-1',
      'name': 'main',
      'provider': 'openai',
      'baseUrl': 'https://api.openai.com/v1',
      'model': 'gpt-4o-mini',
      'maxTokens': 4096,
      'temperature': 0.8,
      'streamEnabled': true,
      'thinkingEnabled': true,
      'reasoningEffort': 'high',
      // 手机端绝不发送 apiKey —— 解析不得抛类型异常
    });

    expect(config, isNotNull);
    expect(config!.id, 'cfg-1');
    expect(config.baseUrl, 'https://api.openai.com/v1');
    expect(config.apiKey, isNull);
    expect(config.maxTokens, 4096);
    expect(config.thinkingEnabled, isTrue);
  });

  test('parses legacy snake_case rows (with api_key present)', () {
    final config = ApiConfig.tryFromJson(const {
      'id': 'cfg-2',
      'name': 'legacy',
      'provider': 'anthropic',
      'base_url': 'https://api.anthropic.com',
      'api_key': 'sk-legacy',
      'model': 'claude-3-5-sonnet',
      'max_tokens': 8192,
      'stream_enabled': 1,
    });

    expect(config, isNotNull);
    expect(config!.baseUrl, 'https://api.anthropic.com');
    expect(config.apiKey, 'sk-legacy');
    expect(config.maxTokens, 8192);
  });

  test('returns null for malformed config instead of throwing', () {
    expect(ApiConfig.tryFromJson(const {'id': 123}), isNull);
    expect(ApiConfig.tryFromJson(const {'id': 'x'}), isNull);
    expect(ApiConfig.tryFromJson(const <String, dynamic>{}), isNull);
  });

  test('type-mismatched optional fields return null instead of throwing', () {
    // maxTokens 为字符串、apiKey 为数字：不得抛 TypeError
    final config = ApiConfig.tryFromJson(const {
      'id': 'cfg-3',
      'name': 'bad types',
      'provider': 'openai',
      'model': 'm',
      'apiKey': 12345,
      'maxTokens': '4096',
      'streamEnabled': 'yes',
    });
    expect(config, isNotNull);
    expect(config!.apiKey, isNull);
    expect(config.maxTokens, isNull);
    expect(config.streamEnabled, isNull);
  });
}
