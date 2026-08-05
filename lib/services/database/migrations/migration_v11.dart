import 'package:sqflite/sqflite.dart';

/// v11：
/// - api_configs 增加 thinking_enabled / reasoning_effort（思考模式配置持久化）
/// - memory_entries 增加 (contact_id, category, key) 唯一索引（防并发重复记忆）
Future<void> migrateV11(Database db) async {
  await db.execute(
    'ALTER TABLE api_configs ADD COLUMN thinking_enabled INTEGER NOT NULL DEFAULT 0',
  );
  await db.execute(
    "ALTER TABLE api_configs ADD COLUMN reasoning_effort TEXT NOT NULL DEFAULT 'high'",
  );

  // 历史版本 check-then-act 可能已产生重复记忆：先清理（保留每组最后一行），
  // 否则唯一索引创建会失败。
  await db.execute('''
    DELETE FROM memory_entries
    WHERE rowid NOT IN (
      SELECT MAX(rowid) FROM memory_entries GROUP BY contact_id, category, key
    )
  ''');
  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_memory_entries_uniq
    ON memory_entries(contact_id, category, key)
  ''');

  // LanSync 删除同步：服务端软删除记录（tombstone），PC 端据此清理 mirror。
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pc_deletions (
      id TEXT PRIMARY KEY,
      table_name TEXT NOT NULL,
      row_id TEXT NOT NULL,
      deleted_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_pc_deletions_table ON pc_deletions(table_name, deleted_at)',
  );
}
