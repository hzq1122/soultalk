import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact.freezed.dart';
part 'contact.g.dart';

@freezed
class Contact with _$Contact {
  const factory Contact({
    required String id,
    required String name,
    String? avatar,           // 本地文件路径或 null（使用首字母头像）
    @Default('') String description,
    String? apiConfigId,      // 绑定的 API 配置 ID
    @Default('') String systemPrompt,
    String? characterCardJson, // SillyTavern 角色卡 JSON 字符串
    @Default([]) List<String> tags,
    @Default(false) bool pinned,
    @Default(0) int unreadCount,
    String? lastMessage,
    DateTime? lastMessageAt,
    @Default(true) bool proactiveEnabled,
    DateTime? lastProactiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Contact;

  factory Contact.fromJson(Map<String, dynamic> json) =>
      _$ContactFromJson(json);
}
