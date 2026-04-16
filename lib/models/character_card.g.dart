// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CharacterCardImpl _$$CharacterCardImplFromJson(Map<String, dynamic> json) =>
    _$CharacterCardImpl(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      personality: json['personality'] as String? ?? '',
      scenario: json['scenario'] as String? ?? '',
      firstMes: json['firstMes'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      mesExample: json['mesExample'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      creator: json['creator'] as String? ?? '',
      creatorNotes: json['creatorNotes'] as String? ?? '',
      avatarBase64: json['avatarBase64'] as String?,
      spec: json['spec'] as String?,
      specVersion: json['specVersion'] as String? ?? '2.0',
    );

Map<String, dynamic> _$$CharacterCardImplToJson(_$CharacterCardImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'personality': instance.personality,
      'scenario': instance.scenario,
      'firstMes': instance.firstMes,
      'systemPrompt': instance.systemPrompt,
      'mesExample': instance.mesExample,
      'tags': instance.tags,
      'creator': instance.creator,
      'creatorNotes': instance.creatorNotes,
      'avatarBase64': instance.avatarBase64,
      'spec': instance.spec,
      'specVersion': instance.specVersion,
    };
