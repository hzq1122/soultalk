import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/friend_circle_rule_dao.dart';
import 'package:soultalk/services/database/migrations/migration_v10.dart';
import 'package:soultalk/services/database/migrations/migration_v13.dart';
import 'package:soultalk/services/database/proactive_event_dao.dart';
import 'package:soultalk/services/database/proactive_rule_dao.dart';

void main() {
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await migrateV10(db);
    await migrateV13(db);
    dbService = _TestDatabaseService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('proactive rule upsert creates then updates per contact', () async {
    final dao = ProactiveRuleDao(dbService);

    final created = await dao.upsertForContact(
      'c-1',
      enabled: true,
      minHours: 4,
      probability: 0.5,
    );
    expect(created.contactId, 'c-1');
    expect(created.minHours, 4);
    expect(created.lastTriggeredAt, isNull);

    final loaded = await dao.getByContact('c-1');
    expect(loaded, isNotNull);
    expect(loaded!.minHours, 4);

    // 再次 upsert 更新参数但不换 id
    final updated = await dao.upsertForContact(
      'c-1',
      minHours: 6,
      probability: 0.2,
    );
    expect(updated.id, created.id);
    expect(updated.minHours, 6);
    expect(updated.probability, 0.2);
    expect((await dao.getByContact('c-1'))!.minHours, 6);
  });

  test('proactive rule enabled list and triggered at update', () async {
    final dao = ProactiveRuleDao(dbService);
    await dao.upsertForContact('c-1', enabled: true);
    await dao.upsertForContact('c-2', enabled: false);

    final enabled = await dao.getAllEnabled();
    expect(enabled.length, 1);
    expect(enabled.single.contactId, 'c-1');

    final at = DateTime.utc(2026, 8, 5, 12);
    await dao.updateTriggeredAt('c-1', at);
    final rule = await dao.getByContact('c-1');
    expect(rule!.lastTriggeredAt, at);
  });

  test('proactive event records and queries recent', () async {
    final dao = ProactiveEventDao(dbService);
    await dao.record(
      contactId: 'c-1',
      ruleId: 'r-1',
      eventType: 'sent',
      status: 'sent',
      payload: '{"content":"hi"}',
    );
    await dao.record(
      contactId: 'c-1',
      eventType: 'failed',
      status: 'failed',
      payload: 'boom',
    );
    await dao.record(contactId: 'c-2', eventType: 'skipped', status: 'skipped');

    final all = await dao.recent();
    expect(all.length, 3);
    expect(all.first.eventType, 'skipped'); // 最新在前

    final forC1 = await dao.recent(contactId: 'c-1');
    expect(forC1.length, 2);
    expect(
      forC1.map((e) => e.status),
      containsAll(['failed', 'sent']),
    );
  });

  test('friend circle rule upsert and posted at update', () async {
    final dao = FriendCircleRuleDao(dbService);
    final created = await dao.upsertForContact('c-1', intervalHours: 48);
    expect(created.intervalHours, 48);
    expect(created.lastPostedAt, isNull);

    final at = DateTime.utc(2026, 8, 5, 9);
    await dao.updatePostedAt('c-1', at);
    final rule = await dao.getByContact('c-1');
    expect(rule!.lastPostedAt, at);

    final updated = await dao.upsertForContact('c-1', intervalHours: 12);
    expect(updated.id, created.id);
    expect(updated.lastPostedAt, at); // 保留既有发布时间
  });

  test('v13 guard fields round-trip and effectiveDailyLimit logic', () async {
    final dao = ProactiveRuleDao(dbService);
    final rule = await dao.upsertForContact(
      'c-1',
      quietStartHour: 22,
      quietEndHour: 8,
      dailyLimit: 5,
      budgetCents: 80, // 折算 8 条；取小 = 5
    );
    expect(rule.quietStartHour, 22);
    expect(rule.quietEndHour, 8);
    expect(rule.effectiveDailyLimit, 5);

    final loaded = await dao.getByContact('c-1');
    expect(loaded!.quietStartHour, 22);
    expect(loaded.quietEndHour, 8);
    expect(loaded.dailyLimit, 5);
    expect(loaded.budgetCents, 80);

    // 仅预算生效：折算条数
    final budgetOnly = await dao.upsertForContact('c-2', budgetCents: 100);
    expect(budgetOnly.effectiveDailyLimit, 10);
    // 均为 0 = 不限
    final unlimited = await dao.upsertForContact('c-3');
    expect(unlimited.effectiveDailyLimit, 0);
  });

  test('countSentToday counts only today sent events', () async {
    final dao = ProactiveEventDao(dbService);
    final now = DateTime.now();
    await dao.record(
      contactId: 'c-1',
      eventType: 'sent',
      status: 'sent',
      payload: 'x',
    );
    // 昨天的事件
    final yesterday = now.subtract(const Duration(days: 1));
    await db.insert('proactive_events', {
      'id': 'old-1',
      'contact_id': 'c-1',
      'event_type': 'sent',
      'status': 'sent',
      'created_at': yesterday.millisecondsSinceEpoch,
    });
    // 其他联系人 / 非 sent 类型不计
    await dao.record(contactId: 'c-2', eventType: 'sent', status: 'sent');
    await dao.record(contactId: 'c-1', eventType: 'failed', status: 'failed');

    expect(await dao.countSentToday('c-1'), 1);
  });
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
