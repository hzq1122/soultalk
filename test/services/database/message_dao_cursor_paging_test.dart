import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/message_dao.dart';

void main() {
  late Database db;
  late MessageDao dao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
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
        created_at TEXT
      )
    ''');
    dao = MessageDao(_TestDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertMsg(String id, String at) {
    return db.insert('messages', {
      'id': id,
      'contact_id': 'c-1',
      'role': 'user',
      'content': 'msg-$id',
      'type': 'text',
      'created_at': at,
    });
  }

  test('cursor pagination walks all pages without duplicates', () async {
    // 12 条消息：前 10 条时间递增，后 2 条与第 10 条同时间（验证 id 二级排序）
    for (var i = 0; i < 10; i++) {
      await insertMsg('m$i', '2026-01-01T00:00:0$i.000');
    }
    await insertMsg('mA', '2026-01-01T00:00:09.000');
    await insertMsg('mB', '2026-01-01T00:00:09.000');

    final all = <String>[];
    DateTime? beforeAt;
    String? beforeId;
    var page = 0;
    while (true) {
      final rows = await dao.getPageByCursor(
        'c-1',
        limit: 5,
        beforeCreatedAt: beforeAt,
        beforeId: beforeId,
      );
      if (rows.isEmpty) break;
      page++;
      for (final m in rows) {
        all.add(m.id);
      }
      beforeAt = rows.last.createdAt;
      beforeId = rows.last.id;
      if (page > 10) fail('pagination did not terminate');
    }

    // 12 条全部取到且不重复（最新在前：mB/mA 与 m9 同时间按 id 降序）
    expect(all.toSet().length, 12);
    expect(all.length, 12);
    expect(all.first, 'mB');
    expect(all, containsAll(['m0', 'm1', 'm2', 'm3', 'm4']));
  });

  test('cursor pagination is stable when new messages arrive', () async {
    await insertMsg('m1', '2026-01-01T00:00:01.000');
    await insertMsg('m2', '2026-01-01T00:00:02.000');
    await insertMsg('m3', '2026-01-01T00:00:03.000');

    // 第一页取最新 2 条
    final page1 = await dao.getPageByCursor('c-1', limit: 2);
    expect(page1.map((m) => m.id).toList(), ['m3', 'm2']);

    // 新消息到达
    await insertMsg('m4', '2026-01-01T00:00:04.000');

    // 第二页基于第一页游标：只取更旧的消息，不受新消息影响
    final page2 = await dao.getPageByCursor(
      'c-1',
      limit: 2,
      beforeCreatedAt: page1.last.createdAt,
      beforeId: page1.last.id,
    );
    expect(page2.map((m) => m.id).toList(), ['m1']);
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
