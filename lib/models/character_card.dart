import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_card.freezed.dart';
part 'character_card.g.dart';

/// SillyTavern V2 角色卡数据模型
@freezed
class CharacterCard with _$CharacterCard {
  const factory CharacterCard({
    required String name,
    @Default('') String description,
    @Default('') String personality,
    @Default('') String scenario,
    @Default('') String firstMes,     // 第一条消息（开场白）
    @Default('') String systemPrompt,
    @Default('') String mesExample,   // 对话示例
    @Default([]) List<String> tags,
    @Default('') String creator,
    @Default('') String creatorNotes,
    String? avatarBase64,             // PNG 图片 base64
    String? spec,                     // 'chara_card_v2'
    @Default('2.0') String specVersion,
  }) = _CharacterCard;

  factory CharacterCard.fromJson(Map<String, dynamic> json) =>
      _$CharacterCardFromJson(json);

  /// 从 SillyTavern V2 格式解析
  factory CharacterCard.fromV2Json(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return CharacterCard(
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      personality: data['personality'] as String? ?? '',
      scenario: data['scenario'] as String? ?? '',
      firstMes: data['first_mes'] as String? ?? '',
      systemPrompt: data['system_prompt'] as String? ?? '',
      mesExample: data['mes_example'] as String? ?? '',
      tags: List<String>.from(data['tags'] as List? ?? []),
      creator: data['creator'] as String? ?? '',
      creatorNotes: data['creator_notes'] as String? ?? '',
      spec: json['spec'] as String?,
      specVersion: json['spec_version'] as String? ?? '2.0',
    );
  }

  const CharacterCard._();

  /// 生成 system prompt（用于 LLM 对话）
  String buildSystemPrompt(String userName) {
    final buffer = StringBuffer();
    if (systemPrompt.isNotEmpty) {
      buffer.writeln(systemPrompt.replaceAll('{{user}}', userName));
    }
    if (description.isNotEmpty) {
      buffer.writeln('\n[Character Description]\n$description');
    }
    if (personality.isNotEmpty) {
      buffer.writeln('\n[Personality]\n$personality');
    }
    if (scenario.isNotEmpty) {
      buffer.writeln('\n[Scenario]\n$scenario');
    }
    if (mesExample.isNotEmpty) {
      buffer.writeln('\n[Example Dialogue]\n$mesExample');
    }
    return buffer.toString().trim();
  }
}
