// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Contact _$ContactFromJson(Map<String, dynamic> json) {
  return _Contact.fromJson(json);
}

/// @nodoc
mixin _$Contact {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get avatar =>
      throw _privateConstructorUsedError; // 本地文件路径或 null（使用首字母头像）
  String get description => throw _privateConstructorUsedError;
  String? get apiConfigId =>
      throw _privateConstructorUsedError; // 绑定的 API 配置 ID
  String get systemPrompt => throw _privateConstructorUsedError;
  String? get characterCardJson =>
      throw _privateConstructorUsedError; // SillyTavern 角色卡 JSON 字符串
  List<String> get tags => throw _privateConstructorUsedError;
  bool get pinned => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;
  String? get lastMessage => throw _privateConstructorUsedError;
  DateTime? get lastMessageAt => throw _privateConstructorUsedError;
  bool get proactiveEnabled => throw _privateConstructorUsedError;
  DateTime? get lastProactiveAt => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Contact to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Contact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContactCopyWith<Contact> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContactCopyWith<$Res> {
  factory $ContactCopyWith(Contact value, $Res Function(Contact) then) =
      _$ContactCopyWithImpl<$Res, Contact>;
  @useResult
  $Res call({
    String id,
    String name,
    String? avatar,
    String description,
    String? apiConfigId,
    String systemPrompt,
    String? characterCardJson,
    List<String> tags,
    bool pinned,
    int unreadCount,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool proactiveEnabled,
    DateTime? lastProactiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$ContactCopyWithImpl<$Res, $Val extends Contact>
    implements $ContactCopyWith<$Res> {
  _$ContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Contact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? avatar = freezed,
    Object? description = null,
    Object? apiConfigId = freezed,
    Object? systemPrompt = null,
    Object? characterCardJson = freezed,
    Object? tags = null,
    Object? pinned = null,
    Object? unreadCount = null,
    Object? lastMessage = freezed,
    Object? lastMessageAt = freezed,
    Object? proactiveEnabled = null,
    Object? lastProactiveAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            avatar: freezed == avatar
                ? _value.avatar
                : avatar // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            apiConfigId: freezed == apiConfigId
                ? _value.apiConfigId
                : apiConfigId // ignore: cast_nullable_to_non_nullable
                      as String?,
            systemPrompt: null == systemPrompt
                ? _value.systemPrompt
                : systemPrompt // ignore: cast_nullable_to_non_nullable
                      as String,
            characterCardJson: freezed == characterCardJson
                ? _value.characterCardJson
                : characterCardJson // ignore: cast_nullable_to_non_nullable
                      as String?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            pinned: null == pinned
                ? _value.pinned
                : pinned // ignore: cast_nullable_to_non_nullable
                      as bool,
            unreadCount: null == unreadCount
                ? _value.unreadCount
                : unreadCount // ignore: cast_nullable_to_non_nullable
                      as int,
            lastMessage: freezed == lastMessage
                ? _value.lastMessage
                : lastMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastMessageAt: freezed == lastMessageAt
                ? _value.lastMessageAt
                : lastMessageAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            proactiveEnabled: null == proactiveEnabled
                ? _value.proactiveEnabled
                : proactiveEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastProactiveAt: freezed == lastProactiveAt
                ? _value.lastProactiveAt
                : lastProactiveAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ContactImplCopyWith<$Res> implements $ContactCopyWith<$Res> {
  factory _$$ContactImplCopyWith(
    _$ContactImpl value,
    $Res Function(_$ContactImpl) then,
  ) = __$$ContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? avatar,
    String description,
    String? apiConfigId,
    String systemPrompt,
    String? characterCardJson,
    List<String> tags,
    bool pinned,
    int unreadCount,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool proactiveEnabled,
    DateTime? lastProactiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ContactImplCopyWithImpl<$Res>
    extends _$ContactCopyWithImpl<$Res, _$ContactImpl>
    implements _$$ContactImplCopyWith<$Res> {
  __$$ContactImplCopyWithImpl(
    _$ContactImpl _value,
    $Res Function(_$ContactImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Contact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? avatar = freezed,
    Object? description = null,
    Object? apiConfigId = freezed,
    Object? systemPrompt = null,
    Object? characterCardJson = freezed,
    Object? tags = null,
    Object? pinned = null,
    Object? unreadCount = null,
    Object? lastMessage = freezed,
    Object? lastMessageAt = freezed,
    Object? proactiveEnabled = null,
    Object? lastProactiveAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ContactImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        avatar: freezed == avatar
            ? _value.avatar
            : avatar // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        apiConfigId: freezed == apiConfigId
            ? _value.apiConfigId
            : apiConfigId // ignore: cast_nullable_to_non_nullable
                  as String?,
        systemPrompt: null == systemPrompt
            ? _value.systemPrompt
            : systemPrompt // ignore: cast_nullable_to_non_nullable
                  as String,
        characterCardJson: freezed == characterCardJson
            ? _value.characterCardJson
            : characterCardJson // ignore: cast_nullable_to_non_nullable
                  as String?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        pinned: null == pinned
            ? _value.pinned
            : pinned // ignore: cast_nullable_to_non_nullable
                  as bool,
        unreadCount: null == unreadCount
            ? _value.unreadCount
            : unreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastMessage: freezed == lastMessage
            ? _value.lastMessage
            : lastMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastMessageAt: freezed == lastMessageAt
            ? _value.lastMessageAt
            : lastMessageAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        proactiveEnabled: null == proactiveEnabled
            ? _value.proactiveEnabled
            : proactiveEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastProactiveAt: freezed == lastProactiveAt
            ? _value.lastProactiveAt
            : lastProactiveAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ContactImpl implements _Contact {
  const _$ContactImpl({
    required this.id,
    required this.name,
    this.avatar,
    this.description = '',
    this.apiConfigId,
    this.systemPrompt = '',
    this.characterCardJson,
    final List<String> tags = const [],
    this.pinned = false,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.proactiveEnabled = true,
    this.lastProactiveAt,
    this.createdAt,
    this.updatedAt,
  }) : _tags = tags;

  factory _$ContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$ContactImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? avatar;
  // 本地文件路径或 null（使用首字母头像）
  @override
  @JsonKey()
  final String description;
  @override
  final String? apiConfigId;
  // 绑定的 API 配置 ID
  @override
  @JsonKey()
  final String systemPrompt;
  @override
  final String? characterCardJson;
  // SillyTavern 角色卡 JSON 字符串
  final List<String> _tags;
  // SillyTavern 角色卡 JSON 字符串
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final bool pinned;
  @override
  @JsonKey()
  final int unreadCount;
  @override
  final String? lastMessage;
  @override
  final DateTime? lastMessageAt;
  @override
  @JsonKey()
  final bool proactiveEnabled;
  @override
  final DateTime? lastProactiveAt;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Contact(id: $id, name: $name, avatar: $avatar, description: $description, apiConfigId: $apiConfigId, systemPrompt: $systemPrompt, characterCardJson: $characterCardJson, tags: $tags, pinned: $pinned, unreadCount: $unreadCount, lastMessage: $lastMessage, lastMessageAt: $lastMessageAt, proactiveEnabled: $proactiveEnabled, lastProactiveAt: $lastProactiveAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContactImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.avatar, avatar) || other.avatar == avatar) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.apiConfigId, apiConfigId) ||
                other.apiConfigId == apiConfigId) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            (identical(other.characterCardJson, characterCardJson) ||
                other.characterCardJson == characterCardJson) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.pinned, pinned) || other.pinned == pinned) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            (identical(other.proactiveEnabled, proactiveEnabled) ||
                other.proactiveEnabled == proactiveEnabled) &&
            (identical(other.lastProactiveAt, lastProactiveAt) ||
                other.lastProactiveAt == lastProactiveAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    avatar,
    description,
    apiConfigId,
    systemPrompt,
    characterCardJson,
    const DeepCollectionEquality().hash(_tags),
    pinned,
    unreadCount,
    lastMessage,
    lastMessageAt,
    proactiveEnabled,
    lastProactiveAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Contact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContactImplCopyWith<_$ContactImpl> get copyWith =>
      __$$ContactImplCopyWithImpl<_$ContactImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ContactImplToJson(this);
  }
}

abstract class _Contact implements Contact {
  const factory _Contact({
    required final String id,
    required final String name,
    final String? avatar,
    final String description,
    final String? apiConfigId,
    final String systemPrompt,
    final String? characterCardJson,
    final List<String> tags,
    final bool pinned,
    final int unreadCount,
    final String? lastMessage,
    final DateTime? lastMessageAt,
    final bool proactiveEnabled,
    final DateTime? lastProactiveAt,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) = _$ContactImpl;

  factory _Contact.fromJson(Map<String, dynamic> json) = _$ContactImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get avatar; // 本地文件路径或 null（使用首字母头像）
  @override
  String get description;
  @override
  String? get apiConfigId; // 绑定的 API 配置 ID
  @override
  String get systemPrompt;
  @override
  String? get characterCardJson; // SillyTavern 角色卡 JSON 字符串
  @override
  List<String> get tags;
  @override
  bool get pinned;
  @override
  int get unreadCount;
  @override
  String? get lastMessage;
  @override
  DateTime? get lastMessageAt;
  @override
  bool get proactiveEnabled;
  @override
  DateTime? get lastProactiveAt;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Contact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContactImplCopyWith<_$ContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
