import 'package:sqflite/sqflite.dart';

/// v12：
/// - messages 增加 is_failed（失败持久化状态：生成失败时保留消息
///   并标记 failed，UI 显示失败样式与重试/重新生成入口，而不是删除占位）。
Future<void> migrateV12(Database db) async {
  await db.execute(
    'ALTER TABLE messages ADD COLUMN is_failed INTEGER NOT NULL DEFAULT 0',
  );
}
