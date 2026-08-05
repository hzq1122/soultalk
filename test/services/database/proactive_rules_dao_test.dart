import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/friend_circle_rule_dao.dart';
import 'package:soultalk/services/database/migrations/migration_v10.dart';
import 'package:soultalk/services/database/proactive_event_dao.dart';
import 'package:soultalk/services/database/proactive_rule_dao.dart';

void main() {
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await migrateV10(db);
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
    expect(forC1.first.status, 'failed');
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
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
