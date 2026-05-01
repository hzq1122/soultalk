import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_card.freezed.dart';
part 'character_card.g.dart';

@freezed
class CharacterCard with _$CharacterCard {
  const factory CharacterCard({
    required String name,
    @Default('') String description,
    @Default('') String personality,
    @Default('') String scenario,
    @Default('') String firstMes,
    @Default('') String systemPrompt,
    @Default('') String mesExample,
    @Default([]) List<String> tags,
    @Default('') String creator,
    @Default('') String creatorNotes,
    String? avatarBase64,
    String? spec,
    @Default('2.0') String specVersion,
    @Default('') String characterVersion,
    @Default([]) List<String> alternateGreetings,
    @Default({}) Map<String, dynamic> extensions,
  }) = _CharacterCard;

  factory CharacterCard.fromJson(Map<String, dynamic> json) =>
      _$CharacterCardFromJson(json);

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
      tags: _parseTags(data['tags']),
      creator: data['creator'] as String? ?? '',
      creatorNotes: data['creator_notes'] as String? ?? '',
      spec: json['spec'] as String?,
      specVersion: json['spec_version'] as String? ?? '2.0',
      characterVersion: data['character_version'] as String? ?? '',
    );
  }

  factory CharacterCard.fromV3Json(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return CharacterCard(
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      personality: data['personality'] as String? ?? '',
      scenario: data['scenario'] as String? ?? '',
      firstMes: data['first_mes'] as String? ?? '',
      systemPrompt: data['system_prompt'] as String? ?? '',
      mesExample: data['mes_example'] as String? ?? '',
      tags: _parseTags(data['tags']),
      creator: data['creator'] as String? ?? '',
      creatorNotes: data['creator_notes'] as String? ?? '',
      spec: json['spec'] as String?,
      specVersion: json['spec_version'] as String? ?? '3.0',
      characterVersion: data['character_version'] as String? ?? '',
      alternateGreetings: _parseStringList(data['alternate_greetings']),
      extensions: data['extensions'] is Map<String, dynamic>
          ? data['extensions'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }

  factory CharacterCard.fromAutoDetectJson(Map<String, dynamic> json) {
    final spec = json['spec'] as String?;
    final specVersion = json['spec_version'] as String?;

    if (spec == 'chara_card_v3' || specVersion == '3.0' || specVersion == '3') {
      return CharacterCard.fromV3Json(json);
    }

    if (spec == 'chara_card_v2' ||
        specVersion == '2.0' ||
        json.containsKey('data')) {
      return CharacterCard.fromV2Json(json);
    }

    return CharacterCard(
      name: json['name'] as String? ?? json['char_name'] as String? ?? '',
      description:
          json['description'] as String? ??
          json['char_description'] as String? ??
          '',
      personality: json['personality'] as String? ?? '',
      scenario: json['scenario'] as String? ?? '',
      firstMes:
          json['first_mes'] as String? ??
          json['first_message'] as String? ??
          json['char_greeting'] as String? ??
          '',
      systemPrompt: json['system_prompt'] as String? ?? '',
      mesExample:
          json['mes_example'] as String? ??
          json['example_dialogue'] as String? ??
          '',
      tags: _parseTags(json['tags']),
      creator: json['creator'] as String? ?? '',
      spec: 'chara_card_v1',
      specVersion: '1.0',
    );
  }

  const CharacterCard._();

  static List<String> _parseTags(dynamic tags) {
    if (tags is List) {
      return tags.map((e) => e.toString()).toList();
    }
    return [];
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  String buildSystemPrompt(String userName, {String charName = ''}) {
    final buffer = StringBuffer();
    if (systemPrompt.isNotEmpty) {
      buffer.writeln(_replaceVars(systemPrompt, userName, charName));
    }
    if (description.isNotEmpty) {
      buffer.writeln(
        '\n[Character Description]\n${_replaceVars(description, userName, charName)}',
      );
    }
    if (personality.isNotEmpty) {
      buffer.writeln(
        '\n[Personality]\n${_replaceVars(personality, userName, charName)}',
      );
    }
    if (scenario.isNotEmpty) {
      buffer.writeln(
        '\n[Scenario]\n${_replaceVars(scenario, userName, charName)}',
      );
    }
    if (mesExample.isNotEmpty) {
      buffer.writeln(
        '\n[Example Dialogue]\n${_replaceVars(mesExample, userName, charName)}',
      );
    }
    return buffer.toString().trim();
  }

  String _replaceVars(String text, String userName, String charName) {
    return text
        .replaceAll('{{user}}', userName)
        .replaceAll('{{char}}', charName.isNotEmpty ? charName : name);
  }
}
