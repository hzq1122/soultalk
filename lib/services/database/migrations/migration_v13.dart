import 'package:sqflite/sqflite.dart';

/// v13：主动消息与朋友圈规则增加防护字段。
/// - quiet_start_hour / quiet_end_hour：安静时段（跨天区间，如 23→7）
/// - daily_limit：每日发送次数上限（0 = 不限）
/// - budget_cents：每日费用预算上限（分；0 = 不限，
///   按约 0.1 元/条估算折算为条数上限参与执行）
Future<void> migrateV13(Database db) async {
  for (final table in ['proactive_rules', 'friend_circle_rules']) {
    await db.execute(
      'ALTER TABLE $table ADD COLUMN quiet_start_hour INTEGER NOT NULL DEFAULT 23',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN quiet_end_hour INTEGER NOT NULL DEFAULT 7',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN daily_limit INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $table ADD COLUMN budget_cents INTEGER NOT NULL DEFAULT 0',
    );
  }
}
