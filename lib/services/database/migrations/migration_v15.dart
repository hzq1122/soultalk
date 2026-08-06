import 'package:sqflite/sqflite.dart';

/// v15：messages.created_at 强制 NOT NULL。
/// 历史版本允许 null，游标分页（created_at DESC, id DESC）遇到 NULL
/// 排序不稳定，可能重复加载或漏掉消息。SQLite 无法 ALTER 列约束，
/// 通过重建表迁移：旧 null 值回填 1970 纪元。
Future<void> migrateV15(Database db) async {
  // 幂等：已迁移则跳过
  final cols = await db.rawQuery('PRAGMA table_info(messages)');
  final createdAtCol = cols.firstWhere(
    (c) => c['name'] == 'created_at',
    orElse: () => const {},
  );
  if (createdAtCol['notnull'] == 1) return;

  await db.execute('PRAGMA foreign_keys=OFF');
  try {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE messages RENAME TO messages_old');
      await txn.execute('''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY,
          contact_id TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'text',
          is_streaming INTEGER NOT NULL DEFAULT 0,
          is_failed INTEGER NOT NULL DEFAULT 0,
          token_count INTEGER NOT NULL DEFAULT 0,
          metadata TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
        )
      ''');
      await txn.execute(
        'INSERT INTO messages (id, contact_id, role, content, type, '
        'is_streaming, is_failed, token_count, metadata, created_at, updated_at) '
        'SELECT id, contact_id, role, content, type, is_streaming, is_failed, '
        "token_count, metadata, COALESCE(created_at, '1970-01-01T00:00:00.000'), "
        'updated_at FROM messages_old',
      );
      await txn.execute('DROP TABLE messages_old');
      await txn.execute(
        'CREATE INDEX idx_messages_contact_id ON messages(contact_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_messages_created_at ON messages(created_at)',
      );
    });
  } finally {
    await db.execute('PRAGMA foreign_keys=ON');
  }
}
