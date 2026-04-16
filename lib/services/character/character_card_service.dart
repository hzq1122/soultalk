import 'dart:convert';
import 'dart:io';
import '../../models/character_card.dart';
import '../../models/contact.dart';

/// 解析 SillyTavern V2 角色卡 JSON 文件，返回 Contact 草稿
class CharacterCardService {
  /// 从 JSON 文件路径读取并解析角色卡
  static Future<Contact?> fromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _buildContact(json, raw);
    } catch (e) {
      return null;
    }
  }

  /// 从 JSON 字符串解析角色卡
  static Contact? fromJsonString(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _buildContact(json, raw);
    } catch (e) {
      return null;
    }
  }

  /// 内部：构建 Contact
  static Contact? _buildContact(Map<String, dynamic> json, String rawJson) {
    final card = CharacterCard.fromV2Json(json);
    if (card.name.isEmpty) return null;

    return Contact(
      id: '', // 由 DAO 生成
      name: card.name,
      description: card.description,
      systemPrompt: card.buildSystemPrompt('用户'),
      tags: card.tags,
      characterCardJson: rawJson,
    );
  }

  /// 校验是否为有效的角色卡 JSON（宽松：只要有 name 字段即可）
  static bool isValidCardJson(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // V2 格式
      if (json['spec'] == 'chara_card_v2') {
        final data = json['data'] as Map<String, dynamic>?;
        return (data?['name'] as String?)?.isNotEmpty == true;
      }
      // V1 格式（直接含 name）
      return (json['name'] as String?)?.isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }
}
