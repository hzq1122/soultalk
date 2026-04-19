// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MomentCommentImpl _$$MomentCommentImplFromJson(Map<String, dynamic> json) =>
    _$MomentCommentImpl(
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      content: json['content'] as String,
      replyToName: json['replyToName'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$MomentCommentImplToJson(_$MomentCommentImpl instance) =>
    <String, dynamic>{
      'authorId': instance.authorId,
      'authorName': instance.authorName,
      'content': instance.content,
      'replyToName': instance.replyToName,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_$MomentImpl _$$MomentImplFromJson(Map<String, dynamic> json) => _$MomentImpl(
  id: json['id'] as String,
  contactId: json['contactId'] as String,
  content: json['content'] as String,
  imageUrl: json['imageUrl'] as String?,
  likes:
      (json['likes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  comments:
      (json['comments'] as List<dynamic>?)
          ?.map((e) => MomentComment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$MomentImplToJson(_$MomentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'contactId': instance.contactId,
      'content': instance.content,
      'imageUrl': instance.imageUrl,
      'likes': instance.likes,
      'comments': instance.comments,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
