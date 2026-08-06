import 'package:sqflite/sqflite.dart';

/// v14：数据变更追踪。
/// - messages 增加 updated_at（回填 created_at）：消息编辑、失败状态、
///   metadata 修改等原地变更不再丢失（自动备份指纹与 LanSync 增量水位
///   依赖该列，之前只比较 count + max(created_at) 会漏掉这些修改）。
/// - moments 增加 updated_at（回填 created_at）：朋友圈点赞/评论修改
///   同样可被指纹与增量同步捕获。
Future<void> migrateV14(Database db) async {
  final tables = <String, String>{
    'messages': 'created_at',
    'moments': 'created_at',
  };
  for (final entry in tables.entries) {
    final table = entry.key;
    // 表不存在（测试用最小 schema）时跳过，避免 ALTER 失败
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [table],
    );
    if (exists.isEmpty) continue;
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final hasUpdatedAt = cols.any((c) => c['name'] == 'updated_at');
    if (hasUpdatedAt) continue;
    await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
    // 回填：历史行以 created_at 作为初始 updated_at
    await db.execute(
      'UPDATE $table SET updated_at = ${entry.value} '
      'WHERE updated_at IS NULL',
    );
  }
}
