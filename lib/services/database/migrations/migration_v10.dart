import 'package:sqflite/sqflite.dart';

/// P3：主动消息与朋友圈规则/事件落库。
///
/// - proactive_rules：每个联系人的主动消息规则（替代/补充 contacts 表字段）
/// - proactive_events：主动消息触发/发送事件日志
/// - friend_circle_rules：每个联系人的朋友圈发布规则
Future<void> migrateV10(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS proactive_rules (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 1,
      min_hours INTEGER NOT NULL DEFAULT 2,
      probability REAL NOT NULL DEFAULT 0.3,
      last_triggered_at TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS proactive_events (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      rule_id TEXT,
      event_type TEXT NOT NULL,
      status TEXT NOT NULL,
      payload TEXT,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_proactive_events_contact ON proactive_events(contact_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_proactive_events_created ON proactive_events(created_at)',
  );
  await db.execute('''
    CREATE TABLE IF NOT EXISTS friend_circle_rules (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 1,
      interval_hours INTEGER NOT NULL DEFAULT 24,
      last_posted_at TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}
