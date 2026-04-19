import 'package:freezed_annotation/freezed_annotation.dart';

part 'moment.freezed.dart';
part 'moment.g.dart';

@freezed
class MomentComment with _$MomentComment {
  const factory MomentComment({
    required String authorId,
    required String authorName,
    required String content,
    String? replyToName,
    DateTime? createdAt,
  }) = _MomentComment;

  factory MomentComment.fromJson(Map<String, dynamic> json) =>
      _$MomentCommentFromJson(json);
}

@freezed
class Moment with _$Moment {
  const factory Moment({
    required String id,
    required String contactId,
    required String content,
    String? imageUrl,
    @Default([]) List<String> likes,
    @Default([]) List<MomentComment> comments,
    DateTime? createdAt,
  }) = _Moment;

  factory Moment.fromJson(Map<String, dynamic> json) =>
      _$MomentFromJson(json);
}
