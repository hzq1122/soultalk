import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_config.freezed.dart';
part 'api_config.g.dart';

enum LlmProvider { openai, anthropic, custom }

@freezed
class ApiConfig with _$ApiConfig {
  const factory ApiConfig({
    required String id,
    required String name,
    @Default(LlmProvider.openai) LlmProvider provider,
    required String baseUrl,
    // API Key 不得出现在任何 JSON 序列化输出（日志/备份/调试）：
    // 序列化统一走 ApiConfigDao（安全存储优先），toJson 永远不含 apiKey
    // ignore: invalid_annotation_target
    @JsonKey(includeToJson: false) required String apiKey,
    @Default('gpt-4o-mini') String model,
    @Default(4096) int maxTokens,
    @Default(0.8) double temperature,
    @Default(true) bool streamEnabled,
    @Default(false) bool thinkingEnabled,
    @Default('high') String reasoningEffort,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ApiConfig;

  factory ApiConfig.fromJson(Map<String, dynamic> json) =>
      _$ApiConfigFromJson(json);
}
