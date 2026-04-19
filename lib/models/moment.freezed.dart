// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'moment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MomentComment _$MomentCommentFromJson(Map<String, dynamic> json) {
  return _MomentComment.fromJson(json);
}

/// @nodoc
mixin _$MomentComment {
  String get authorId => throw _privateConstructorUsedError;
  String get authorName => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String? get replyToName => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this MomentComment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MomentComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MomentCommentCopyWith<MomentComment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MomentCommentCopyWith<$Res> {
  factory $MomentCommentCopyWith(
    MomentComment value,
    $Res Function(MomentComment) then,
  ) = _$MomentCommentCopyWithImpl<$Res, MomentComment>;
  @useResult
  $Res call({
    String authorId,
    String authorName,
    String content,
    String? replyToName,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$MomentCommentCopyWithImpl<$Res, $Val extends MomentComment>
    implements $MomentCommentCopyWith<$Res> {
  _$MomentCommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MomentComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? authorId = null,
    Object? authorName = null,
    Object? content = null,
    Object? replyToName = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            authorId: null == authorId
                ? _value.authorId
                : authorId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorName: null == authorName
                ? _value.authorName
                : authorName // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            replyToName: freezed == replyToName
                ? _value.replyToName
                : replyToName // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MomentCommentImplCopyWith<$Res>
    implements $MomentCommentCopyWith<$Res> {
  factory _$$MomentCommentImplCopyWith(
    _$MomentCommentImpl value,
    $Res Function(_$MomentCommentImpl) then,
  ) = __$$MomentCommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String authorId,
    String authorName,
    String content,
    String? replyToName,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$MomentCommentImplCopyWithImpl<$Res>
    extends _$MomentCommentCopyWithImpl<$Res, _$MomentCommentImpl>
    implements _$$MomentCommentImplCopyWith<$Res> {
  __$$MomentCommentImplCopyWithImpl(
    _$MomentCommentImpl _value,
    $Res Function(_$MomentCommentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MomentComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? authorId = null,
    Object? authorName = null,
    Object? content = null,
    Object? replyToName = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$MomentCommentImpl(
        authorId: null == authorId
            ? _value.authorId
            : authorId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorName: null == authorName
            ? _value.authorName
            : authorName // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        replyToName: freezed == replyToName
            ? _value.replyToName
            : replyToName // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MomentCommentImpl implements _MomentComment {
  const _$MomentCommentImpl({
    required this.authorId,
    required this.authorName,
    required this.content,
    this.replyToName,
    this.createdAt,
  });

  factory _$MomentCommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$MomentCommentImplFromJson(json);

  @override
  final String authorId;
  @override
  final String authorName;
  @override
  final String content;
  @override
  final String? replyToName;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'MomentComment(authorId: $authorId, authorName: $authorName, content: $content, replyToName: $replyToName, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MomentCommentImpl &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.authorName, authorName) ||
                other.authorName == authorName) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.replyToName, replyToName) ||
                other.replyToName == replyToName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    authorId,
    authorName,
    content,
    replyToName,
    createdAt,
  );

  /// Create a copy of MomentComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MomentCommentImplCopyWith<_$MomentCommentImpl> get copyWith =>
      __$$MomentCommentImplCopyWithImpl<_$MomentCommentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MomentCommentImplToJson(this);
  }
}

abstract class _MomentComment implements MomentComment {
  const factory _MomentComment({
    required final String authorId,
    required final String authorName,
    required final String content,
    final String? replyToName,
    final DateTime? createdAt,
  }) = _$MomentCommentImpl;

  factory _MomentComment.fromJson(Map<String, dynamic> json) =
      _$MomentCommentImpl.fromJson;

  @override
  String get authorId;
  @override
  String get authorName;
  @override
  String get content;
  @override
  String? get replyToName;
  @override
  DateTime? get createdAt;

  /// Create a copy of MomentComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MomentCommentImplCopyWith<_$MomentCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Moment _$MomentFromJson(Map<String, dynamic> json) {
  return _Moment.fromJson(json);
}

/// @nodoc
mixin _$Moment {
  String get id => throw _privateConstructorUsedError;
  String get contactId => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  List<String> get likes => throw _privateConstructorUsedError;
  List<MomentComment> get comments => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Moment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Moment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MomentCopyWith<Moment> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MomentCopyWith<$Res> {
  factory $MomentCopyWith(Moment value, $Res Function(Moment) then) =
      _$MomentCopyWithImpl<$Res, Moment>;
  @useResult
  $Res call({
    String id,
    String contactId,
    String content,
    String? imageUrl,
    List<String> likes,
    List<MomentComment> comments,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$MomentCopyWithImpl<$Res, $Val extends Moment>
    implements $MomentCopyWith<$Res> {
  _$MomentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Moment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? contactId = null,
    Object? content = null,
    Object? imageUrl = freezed,
    Object? likes = null,
    Object? comments = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            contactId: null == contactId
                ? _value.contactId
                : contactId // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            likes: null == likes
                ? _value.likes
                : likes // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            comments: null == comments
                ? _value.comments
                : comments // ignore: cast_nullable_to_non_nullable
                      as List<MomentComment>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MomentImplCopyWith<$Res> implements $MomentCopyWith<$Res> {
  factory _$$MomentImplCopyWith(
    _$MomentImpl value,
    $Res Function(_$MomentImpl) then,
  ) = __$$MomentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String contactId,
    String content,
    String? imageUrl,
    List<String> likes,
    List<MomentComment> comments,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$MomentImplCopyWithImpl<$Res>
    extends _$MomentCopyWithImpl<$Res, _$MomentImpl>
    implements _$$MomentImplCopyWith<$Res> {
  __$$MomentImplCopyWithImpl(
    _$MomentImpl _value,
    $Res Function(_$MomentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Moment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? contactId = null,
    Object? content = null,
    Object? imageUrl = freezed,
    Object? likes = null,
    Object? comments = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$MomentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        contactId: null == contactId
            ? _value.contactId
            : contactId // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        likes: null == likes
            ? _value._likes
            : likes // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        comments: null == comments
            ? _value._comments
            : comments // ignore: cast_nullable_to_non_nullable
                  as List<MomentComment>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MomentImpl implements _Moment {
  const _$MomentImpl({
    required this.id,
    required this.contactId,
    required this.content,
    this.imageUrl,
    final List<String> likes = const [],
    final List<MomentComment> comments = const [],
    this.createdAt,
  }) : _likes = likes,
       _comments = comments;

  factory _$MomentImpl.fromJson(Map<String, dynamic> json) =>
      _$$MomentImplFromJson(json);

  @override
  final String id;
  @override
  final String contactId;
  @override
  final String content;
  @override
  final String? imageUrl;
  final List<String> _likes;
  @override
  @JsonKey()
  List<String> get likes {
    if (_likes is EqualUnmodifiableListView) return _likes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_likes);
  }

  final List<MomentComment> _comments;
  @override
  @JsonKey()
  List<MomentComment> get comments {
    if (_comments is EqualUnmodifiableListView) return _comments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_comments);
  }

  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'Moment(id: $id, contactId: $contactId, content: $content, imageUrl: $imageUrl, likes: $likes, comments: $comments, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MomentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.contactId, contactId) ||
                other.contactId == contactId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            const DeepCollectionEquality().equals(other._likes, _likes) &&
            const DeepCollectionEquality().equals(other._comments, _comments) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    contactId,
    content,
    imageUrl,
    const DeepCollectionEquality().hash(_likes),
    const DeepCollectionEquality().hash(_comments),
    createdAt,
  );

  /// Create a copy of Moment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MomentImplCopyWith<_$MomentImpl> get copyWith =>
      __$$MomentImplCopyWithImpl<_$MomentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MomentImplToJson(this);
  }
}

abstract class _Moment implements Moment {
  const factory _Moment({
    required final String id,
    required final String contactId,
    required final String content,
    final String? imageUrl,
    final List<String> likes,
    final List<MomentComment> comments,
    final DateTime? createdAt,
  }) = _$MomentImpl;

  factory _Moment.fromJson(Map<String, dynamic> json) = _$MomentImpl.fromJson;

  @override
  String get id;
  @override
  String get contactId;
  @override
  String get content;
  @override
  String? get imageUrl;
  @override
  List<String> get likes;
  @override
  List<MomentComment> get comments;
  @override
  DateTime? get createdAt;

  /// Create a copy of Moment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MomentImplCopyWith<_$MomentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
