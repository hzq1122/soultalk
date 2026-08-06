import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../services/database/database_service.dart';

/// 处理消息同步相关逻辑
class SyncHandler {
  final DatabaseService dbService;

  SyncHandler({DatabaseService? dbService})
    : dbService = dbService ?? DatabaseService();

  /// 获取同步数据（按修改时间水位：COALESCE(updated_at, created_at)）。
  /// [since] 兼容旧字段语义（created_at > since 曾丢失原地修改）。
  Future<Map<String, dynamic>> getSyncData({
    DateTime? since,
    int limit = 20,
  }) async {
    final db = await dbService.database;
    final where = since == null ? null : 'COALESCE(updated_at, created_at) > ?';
    final whereArgs = since == null ? null : [since.toIso8601String()];
    final messages = await db.query(
      'messages',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'COALESCE(updated_at, created_at) ASC, id ASC',
      limit: limit,
    );
    return {
      'messages': messages,
      'serverTime': DateTime.now().toIso8601String(),
      'hasMore': messages.length == limit,
    };
  }

  /// 计算 Merkle Root 用于同步检查。
  ///
  /// 规范化规则与 PC 端 mirror 完全一致：
  /// 1. snake_case 行 → camelCase 字段（与 PC PullSyncService 映射相同）；
  /// 2. 每行按 key 排序后 JSON 编码（消除字段顺序差异）；
  /// 3. 行哈希列表排序后构建 Merkle（消除行顺序差异）。
  /// 两端用同一规则计算，校验才能一致。
  Future<String> calculateMerkleRoot({DateTime? since}) async {
    final data = await getSyncData(since: since, limit: 1000);
    final messages = data['messages'] as List<dynamic>;

    if (messages.isEmpty) {
      return sha256.convert(utf8.encode('empty')).toString();
    }

    final hashes = messages.map((m) {
      final row = _toCamelRow((m as Map).cast<String, dynamic>());
      final sorted = Map<String, dynamic>.fromEntries(
        row.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
    }).toList()..sort();

    return _calculateMerkleRoot(hashes);
  }

  /// snake_case DB 行 → camelCase（与 PC 端 PullSyncService 映射一致，
  /// 保证两端 Merkle 校验基于同一逻辑内容）。
  static const Map<String, String> _snakeToCamel = {
    'contact_id': 'contactId',
    'api_config_id': 'apiConfigId',
    'character_card_json': 'characterCardJson',
    'unread_count': 'unreadCount',
    'last_message': 'lastMessage',
    'last_message_at': 'lastMessageAt',
    'proactive_enabled': 'proactiveEnabled',
    'last_proactive_at': 'lastProactiveAt',
    'is_streaming': 'isStreaming',
    'token_count': 'tokenCount',
    'created_at': 'timestamp',
    'updated_at': 'updatedAt',
    'image_url': 'imageUrl',
    'script_name': 'scriptName',
    'find_regex': 'findRegex',
    'replace_string': 'replaceString',
    'trim_strings': 'trimStrings',
    'markdown_only': 'markdownOnly',
    'prompt_only': 'promptOnly',
    'run_on_edit': 'runOnEdit',
    'substitute_regex': 'substituteRegex',
    'min_depth': 'minDepth',
    'max_depth': 'maxDepth',
    'slot_name': 'slotName',
    'slot_value': 'slotValue',
    'slot_type': 'slotType',
    'card_type': 'cardType',
  };

  Map<String, dynamic> _toCamelRow(Map<String, dynamic> row) {
    final result = <String, dynamic>{};
    for (final entry in row.entries) {
      result[_snakeToCamel[entry.key] ?? _toCamel(entry.key)] = entry.value;
    }
    return result;
  }

  String _toCamel(String key) {
    final parts = key.split('_');
    if (parts.length == 1) return key;
    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join();
  }

  String _calculateMerkleRoot(List<String> hashes) {
    if (hashes.isEmpty) {
      return sha256.convert(utf8.encode('')).toString();
    }

    if (hashes.length == 1) {
      return hashes.first;
    }

    final nextLevel = <String>[];
    for (var i = 0; i < hashes.length; i += 2) {
      if (i + 1 < hashes.length) {
        final combined = hashes[i] + hashes[i + 1];
        nextLevel.add(sha256.convert(utf8.encode(combined)).toString());
      } else {
        nextLevel.add(hashes[i]);
      }
    }

    return _calculateMerkleRoot(nextLevel);
  }

  /// 应用冲突解决方案
  Future<void> applyResolutions(List<dynamic> resolutions) async {
    for (final resolution in resolutions) {
      final action = resolution['action'] as String;
      final messageId = resolution['messageId'] as String?;
      final content = resolution['content'] as String?;

      switch (action) {
        case 'keep_mobile':
          // 保留手机版，不做操作
          break;
        case 'keep_pc':
          // 用电脑版替换手机版
          if (messageId != null && content != null) {
            await _replaceMessage(messageId, content);
          }
          break;
        case 'manual_edit':
          // 用手动编辑的内容覆盖
          if (messageId != null && content != null) {
            await _replaceMessage(messageId, content);
          }
          break;
      }
    }
  }

  Future<void> _replaceMessage(String messageId, String content) async {
    final db = await dbService.database;
    await db.update(
      'messages',
      {
        'content': content,
        // 冲突决议属于原地修改：刷新 updated_at，
        // 否则 LanSync 水位与自动备份指纹捕获不到该变更
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
