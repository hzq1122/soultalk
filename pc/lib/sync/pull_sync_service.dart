import '../websocket_client.dart';
import '../services/database/pc_mirror_dao.dart';

class PullSyncService {
  final WebSocketClient client;
  final PcMirrorDao mirrorDao;

  /// 会话内增量水位：每表最后拉取到的时间戳。
  /// 首次为 null（全量），之后增量拉取修改的行。
  final Map<String, String> _watermarks = {};

  PullSyncService({required this.client, PcMirrorDao? mirrorDao})
    : mirrorDao = mirrorDao ?? PcMirrorDao();

  /// 当前会话水位（测试/诊断用）。
  String? watermarkFor(String table) => _watermarks[table];

  /// 记录某表最后一条拉取行的时间戳作为下次增量水位。
  void recordWatermark(String table, Map<String, dynamic> lastRow) {
    final ts = (lastRow['updated_at'] ?? lastRow['created_at'])?.toString();
    if (ts != null && ts.isNotEmpty) {
      _watermarks[table] = ts;
    }
  }

  void requestManifest() {
    client.sendRaw({'type': 'manifest.request', 'payload': {}});
  }

  void requestTable(
    String table, {
    List<String>? ids,
    int limit = 500,
    String? after,

    /// 修改水位游标：COALESCE(updated_at, created_at) > afterUpdatedAt
    /// （原地修改的行会被重新拉取）。与 [after] 组合构成精确续拉。
    String? afterUpdatedAt,
  }) {
    final payload = <String, dynamic>{'table': table, 'limit': limit};
    if (ids != null) {
      payload['ids'] = ids;
    }
    if (after != null) {
      payload['after'] = after;
    }
    // 未显式指定水位时使用会话内增量水位（首次为全量）
    final effectiveWatermark = afterUpdatedAt ?? _watermarks[table];
    if (effectiveWatermark != null) {
      payload['afterUpdatedAt'] = effectiveWatermark;
    }
    client.sendRaw({'type': 'pull.request', 'payload': payload});
  }

  Future<void> handlePullChunk(Map<String, dynamic> event) async {
    final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
    if (payload == null) return;
    final table = payload['table'] as String?;
    final rows = (payload['rows'] as List?)?.cast<Map>();
    if (table == null || rows == null) return;

    if (table == 'pc_deletions') {
      // 删除同步（tombstone）：不写入 mirror，直接删除对应行
      final deletions = rows.map((row) => row.cast<String, dynamic>()).toList();
      final byTable = <String, List<String>>{};
      for (final deletion in deletions) {
        final targetTable = deletion['table_name']?.toString();
        final rowId = deletion['row_id']?.toString();
        if (targetTable == null || rowId == null) continue;
        byTable.putIfAbsent(targetTable, () => []).add(rowId);
      }
      for (final entry in byTable.entries) {
        await mirrorDao.deleteRows(entry.key, entry.value);
      }
      return;
    }

    // 统一字段映射：数据库 snake_case → PC UI camelCase
    // （contact_id→contactId、created_at→timestamp 等）
    await mirrorDao.upsertRows(
      table,
      rows.map((row) => _mapFields(row.cast<String, dynamic>())).toList(),
    );
  }

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

  /// 数据库行 → PC 端字段名。未知 snake_case 键也转为 camelCase，
  /// 已存在的 camelCase 键保持原样。
  Map<String, dynamic> _mapFields(Map<String, dynamic> row) {
    final result = <String, dynamic>{};
    for (final entry in row.entries) {
      final mapped = _snakeToCamel[entry.key] ?? _toCamel(entry.key);
      result[mapped] = entry.value;
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
}
