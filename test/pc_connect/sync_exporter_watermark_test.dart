import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/pc_connect/sync_exporter.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v14.dart';

/// SyncExporter 修改水位（updated_at）增量导出测试：
/// 覆盖「已有记录的原地修改能被重新拉取」的核心场景。
void main() {
  late Database db;
  late SyncExporter exporter;

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
    await migrateV14(db);
    await db.insert('messages', {
      'id': 'm-old',
      'contact_id': 'c-1',
      'role': 'user',
      'content': 'original',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    exporter = SyncExporter(dbService: _TestDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('supportsUpdatedAtWatermark 对带 updated_at 的表返回 true', () async {
    expect(await exporter.supportsUpdatedAtWatermark('messages'), isTrue);
  });

  test('水位之前的历史行不会重复导出', () async {
    final data = await exporter.exportRows(
      table: 'messages',
      afterUpdatedAt: '2026-01-02T00:00:00.000',
    );
    expect(data['rows'], isEmpty);
  });

  test('原地修改（仅 updated_at 变化）后按水位重新导出', () async {
    // 初始：水位 2026-01-02 之后无新行
    var data = await exporter.exportRows(
      table: 'messages',
      afterUpdatedAt: '2026-01-02T00:00:00.000',
    );
    expect(data['rows'], isEmpty);

    // 原地编辑：created_at 不变，updated_at 刷新
    await db.update(
      'messages',
      {'content': 'edited in place', 'updated_at': '2026-02-01T00:00:00.000'},
      where: 'id = ?',
      whereArgs: ['m-old'],
    );

    // 旧链路（id > after）无法发现该修改；水位链路必须重新导出
    data = await exporter.exportRows(
      table: 'messages',
      afterUpdatedAt: '2026-01-02T00:00:00.000',
    );
    final rows = data['rows'] as List;
    expect(rows, hasLength(1));
    expect((rows.single as Map)['content'], 'edited in place');
    expect((rows.single as Map)['id'], 'm-old');
  });

  test('复合游标（updatedAt + id）分页续拉无重复无遗漏', () async {
    // 两条时间相同的历史消息 + 一条修改
    await db.insert('messages', {
      'id': 'm-b',
      'contact_id': 'c-1',
      'role': 'assistant',
      'content': 'second',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    await db.update(
      'messages',
      {'updated_at': '2026-03-01T00:00:00.000'},
      where: 'id = ?',
      whereArgs: ['m-b'],
    );

    // 第一页：limit=1，按 COALESCE(updated_at, created_at) ASC, id ASC
    var data = await exporter.exportRows(
      table: 'messages',
      afterUpdatedAt: '2026-01-01T00:00:00.000',
      limit: 1,
    );
    expect(data['hasMore'], isTrue);
    final first = (data['rows'] as List).single as Map;

    // 续拉：用第一页最后一条的 updatedAt + id 复合游标
    data = await exporter.exportRows(
      table: 'messages',
      afterUpdatedAt: first['updated_at'] as String,
      after: first['id'] as String,
      limit: 1,
    );
    final rows = data['rows'] as List;
    expect(rows, hasLength(1));
    final second = rows.single as Map;
    // 时间相同则按 id 精确续拉：m-b > m-old
    expect(second['id'], 'm-b');
    expect(second['content'], 'second');

    // 第三页应为空（全部拉完，服务端下发 pull.complete）
    data = await exporter.exportRows(
      table: 'messages',
      afterUpdatedAt: second['updated_at'] as String,
      after: second['id'] as String,
      limit: 1,
    );
    expect(data['rows'], isEmpty);
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
