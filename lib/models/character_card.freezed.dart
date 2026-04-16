// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'character_card.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CharacterCard _$CharacterCardFromJson(Map<String, dynamic> json) {
  return _CharacterCard.fromJson(json);
}

/// @nodoc
mixin _$CharacterCard {
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get personality => throw _privateConstructorUsedError;
  String get scenario => throw _privateConstructorUsedError;
  String get firstMes => throw _privateConstructorUsedError; // 第一条消息（开场白）
  String get systemPrompt => throw _privateConstructorUsedError;
  String get mesExample => throw _privateConstructorUsedError; // 对话示例
  List<String> get tags => throw _privateConstructorUsedError;
  String get creator => throw _privateConstructorUsedError;
  String get creatorNotes => throw _privateConstructorUsedError;
  String? get avatarBase64 =>
      throw _privateConstructorUsedError; // PNG 图片 base64
  String? get spec => throw _privateConstructorUsedError; // 'chara_card_v2'
  String get specVersion => throw _privateConstructorUsedError;

  /// Serializes this CharacterCard to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CharacterCard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CharacterCardCopyWith<CharacterCard> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterCardCopyWith<$Res> {
  factory $CharacterCardCopyWith(
    CharacterCard value,
    $Res Function(CharacterCard) then,
  ) = _$CharacterCardCopyWithImpl<$Res, CharacterCard>;
  @useResult
  $Res call({
    String name,
    String description,
    String personality,
    String scenario,
    String firstMes,
    String systemPrompt,
    String mesExample,
    List<String> tags,
    String creator,
    String creatorNotes,
    String? avatarBase64,
    String? spec,
    String specVersion,
  });
}

/// @nodoc
class _$CharacterCardCopyWithImpl<$Res, $Val extends CharacterCard>
    implements $CharacterCardCopyWith<$Res> {
  _$CharacterCardCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CharacterCard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? personality = null,
    Object? scenario = null,
    Object? firstMes = null,
    Object? systemPrompt = null,
    Object? mesExample = null,
    Object? tags = null,
    Object? creator = null,
    Object? creatorNotes = null,
    Object? avatarBase64 = freezed,
    Object? spec = freezed,
    Object? specVersion = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            personality: null == personality
                ? _value.personality
                : personality // ignore: cast_nullable_to_non_nullable
                      as String,
            scenario: null == scenario
                ? _value.scenario
                : scenario // ignore: cast_nullable_to_non_nullable
                      as String,
            firstMes: null == firstMes
                ? _value.firstMes
                : firstMes // ignore: cast_nullable_to_non_nullable
                      as String,
            systemPrompt: null == systemPrompt
                ? _value.systemPrompt
                : systemPrompt // ignore: cast_nullable_to_non_nullable
                      as String,
            mesExample: null == mesExample
                ? _value.mesExample
                : mesExample // ignore: cast_nullable_to_non_nullable
                      as String,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            creator: null == creator
                ? _value.creator
                : creator // ignore: cast_nullable_to_non_nullable
                      as String,
            creatorNotes: null == creatorNotes
                ? _value.creatorNotes
                : creatorNotes // ignore: cast_nullable_to_non_nullable
                      as String,
            avatarBase64: freezed == avatarBase64
                ? _value.avatarBase64
                : avatarBase64 // ignore: cast_nullable_to_non_nullable
                      as String?,
            spec: freezed == spec
                ? _value.spec
                : spec // ignore: cast_nullable_to_non_nullable
                      as String?,
            specVersion: null == specVersion
                ? _value.specVersion
                : specVersion // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CharacterCardImplCopyWith<$Res>
    implements $CharacterCardCopyWith<$Res> {
  factory _$$CharacterCardImplCopyWith(
    _$CharacterCardImpl value,
    $Res Function(_$CharacterCardImpl) then,
  ) = __$$CharacterCardImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String description,
    String personality,
    String scenario,
    String firstMes,
    String systemPrompt,
    String mesExample,
    List<String> tags,
    String creator,
    String creatorNotes,
    String? avatarBase64,
    String? spec,
    String specVersion,
  });
}

/// @nodoc
class __$$CharacterCardImplCopyWithImpl<$Res>
    extends _$CharacterCardCopyWithImpl<$Res, _$CharacterCardImpl>
    implements _$$CharacterCardImplCopyWith<$Res> {
  __$$CharacterCardImplCopyWithImpl(
    _$CharacterCardImpl _value,
    $Res Function(_$CharacterCardImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CharacterCard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? personality = null,
    Object? scenario = null,
    Object? firstMes = null,
    Object? systemPrompt = null,
    Object? mesExample = null,
    Object? tags = null,
    Object? creator = null,
    Object? creatorNotes = null,
    Object? avatarBase64 = freezed,
    Object? spec = freezed,
    Object? specVersion = null,
  }) {
    return _then(
      _$CharacterCardImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        personality: null == personality
            ? _value.personality
            : personality // ignore: cast_nullable_to_non_nullable
                  as String,
        scenario: null == scenario
            ? _value.scenario
            : scenario // ignore: cast_nullable_to_non_nullable
                  as String,
        firstMes: null == firstMes
            ? _value.firstMes
            : firstMes // ignore: cast_nullable_to_non_nullable
                  as String,
        systemPrompt: null == systemPrompt
            ? _value.systemPrompt
            : systemPrompt // ignore: cast_nullable_to_non_nullable
                  as String,
        mesExample: null == mesExample
            ? _value.mesExample
            : mesExample // ignore: cast_nullable_to_non_nullable
                  as String,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        creator: null == creator
            ? _value.creator
            : creator // ignore: cast_nullable_to_non_nullable
                  as String,
        creatorNotes: null == creatorNotes
            ? _value.creatorNotes
            : creatorNotes // ignore: cast_nullable_to_non_nullable
                  as String,
        avatarBase64: freezed == avatarBase64
            ? _value.avatarBase64
            : avatarBase64 // ignore: cast_nullable_to_non_nullable
                  as String?,
        spec: freezed == spec
            ? _value.spec
            : spec // ignore: cast_nullable_to_non_nullable
                  as String?,
        specVersion: null == specVersion
            ? _value.specVersion
            : specVersion // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CharacterCardImpl extends _CharacterCard {
  const _$CharacterCardImpl({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMes = '',
    this.systemPrompt = '',
    this.mesExample = '',
    final List<String> tags = const [],
    this.creator = '',
    this.creatorNotes = '',
    this.avatarBase64,
    this.spec,
    this.specVersion = '2.0',
  }) : _tags = tags,
       super._();

  factory _$CharacterCardImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterCardImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final String personality;
  @override
  @JsonKey()
  final String scenario;
  @override
  @JsonKey()
  final String firstMes;
  // 第一条消息（开场白）
  @override
  @JsonKey()
  final String systemPrompt;
  @override
  @JsonKey()
  final String mesExample;
  // 对话示例
  final List<String> _tags;
  // 对话示例
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final String creator;
  @override
  @JsonKey()
  final String creatorNotes;
  @override
  final String? avatarBase64;
  // PNG 图片 base64
  @override
  final String? spec;
  // 'chara_card_v2'
  @override
  @JsonKey()
  final String specVersion;

  @override
  String toString() {
    return 'CharacterCard(name: $name, description: $description, personality: $personality, scenario: $scenario, firstMes: $firstMes, systemPrompt: $systemPrompt, mesExample: $mesExample, tags: $tags, creator: $creator, creatorNotes: $creatorNotes, avatarBase64: $avatarBase64, spec: $spec, specVersion: $specVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterCardImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.personality, personality) ||
                other.personality == personality) &&
            (identical(other.scenario, scenario) ||
                other.scenario == scenario) &&
            (identical(other.firstMes, firstMes) ||
                other.firstMes == firstMes) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            (identical(other.mesExample, mesExample) ||
                other.mesExample == mesExample) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.creatorNotes, creatorNotes) ||
                other.creatorNotes == creatorNotes) &&
            (identical(other.avatarBase64, avatarBase64) ||
                other.avatarBase64 == avatarBase64) &&
            (identical(other.spec, spec) || other.spec == spec) &&
            (identical(other.specVersion, specVersion) ||
                other.specVersion == specVersion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    description,
    personality,
    scenario,
    firstMes,
    systemPrompt,
    mesExample,
    const DeepCollectionEquality().hash(_tags),
    creator,
    creatorNotes,
    avatarBase64,
    spec,
    specVersion,
  );

  /// Create a copy of CharacterCard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterCardImplCopyWith<_$CharacterCardImpl> get copyWith =>
      __$$CharacterCardImplCopyWithImpl<_$CharacterCardImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterCardImplToJson(this);
  }
}

abstract class _CharacterCard extends CharacterCard {
  const factory _CharacterCard({
    required final String name,
    final String description,
    final String personality,
    final String scenario,
    final String firstMes,
    final String systemPrompt,
    final String mesExample,
    final List<String> tags,
    final String creator,
    final String creatorNotes,
    final String? avatarBase64,
    final String? spec,
    final String specVersion,
  }) = _$CharacterCardImpl;
  const _CharacterCard._() : super._();

  factory _CharacterCard.fromJson(Map<String, dynamic> json) =
      _$CharacterCardImpl.fromJson;

  @override
  String get name;
  @override
  String get description;
  @override
  String get personality;
  @override
  String get scenario;
  @override
  String get firstMes; // 第一条消息（开场白）
  @override
  String get systemPrompt;
  @override
  String get mesExample; // 对话示例
  @override
  List<String> get tags;
  @override
  String get creator;
  @override
  String get creatorNotes;
  @override
  String? get avatarBase64; // PNG 图片 base64
  @override
  String? get spec; // 'chara_card_v2'
  @override
  String get specVersion;

  /// Create a copy of CharacterCard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CharacterCardImplCopyWith<_$CharacterCardImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
