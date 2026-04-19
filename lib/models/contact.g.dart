// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ContactImpl _$$ContactImplFromJson(Map<String, dynamic> json) =>
    _$ContactImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      description: json['description'] as String? ?? '',
      apiConfigId: json['apiConfigId'] as String?,
      systemPrompt: json['systemPrompt'] as String? ?? '',
      characterCardJson: json['characterCardJson'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      pinned: json['pinned'] as bool? ?? false,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      proactiveEnabled: json['proactiveEnabled'] as bool? ?? true,
      lastProactiveAt: json['lastProactiveAt'] == null
          ? null
          : DateTime.parse(json['lastProactiveAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ContactImplToJson(_$ContactImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
      'description': instance.description,
      'apiConfigId': instance.apiConfigId,
      'systemPrompt': instance.systemPrompt,
      'characterCardJson': instance.characterCardJson,
      'tags': instance.tags,
      'pinned': instance.pinned,
      'unreadCount': instance.unreadCount,
      'lastMessage': instance.lastMessage,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'proactiveEnabled': instance.proactiveEnabled,
      'lastProactiveAt': instance.lastProactiveAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
