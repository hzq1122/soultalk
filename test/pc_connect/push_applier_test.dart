import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/pc_connect/push/push_applier.dart';
import 'package:soultalk/services/database/database_service.dart';

/// PushApplier.apply 闭环测试：校验通过后真正写库。
void main() {
  late Database db;
  late DatabaseService dbService;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // 与 DatabaseService._onConfigure 一致，启用外键约束
    await db.execute('PRAGMA foreign_keys=ON');
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
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
        created_at TEXT,
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
      )
    ''');
    await db.insert('contacts', {'id': 'c-1', 'name': 'Alice'});
    dbService = _TestDatabaseService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('valid push insert is applied to database', () async {
    final result = await PushApplier(dbService: dbService).apply({
      'table': 'messages',
      'operation': 'insert',
      'row': {
        'id': 'm-1',
        'contact_id': 'c-1',
        'role': 'assistant',
        'content': 'hello from PC',
      },
    });

    expect(result['accepted'], isTrue);
    expect(result['applied'], isTrue);

    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: ['m-1'],
    );
    expect(rows.single['content'], 'hello from PC');
  });

  test('duplicate push insert is not applied twice', () async {
    final applier = PushApplier(dbService: dbService);
    final proposal = {
      'table': 'messages',
      'operation': 'insert',
      'row': {
        'id': 'm-1',
        'contact_id': 'c-1',
        'role': 'assistant',
        'content': 'first',
      },
    };

    expect((await applier.apply(proposal))['applied'], isTrue);
    final second = await applier.apply(proposal);
    expect(second['applied'], isFalse);
    expect(second['reason'], 'duplicate');

    final rows = await db.query('messages');
    expect(rows.length, 1);
  });

  test('non-allowed table is rejected before apply', () async {
    final result = await PushApplier(dbService: dbService).apply({
      'table': 'contacts',
      'operation': 'insert',
      'row': {'id': 'x', 'name': 'evil'},
    });

    expect(result['accepted'], isFalse);
    expect(result['reason'], 'table_not_allowed');
  });

  test('secret fields are rejected', () async {
    final result = await PushApplier(dbService: dbService).apply({
      'table': 'messages',
      'operation': 'insert',
      'row': {'id': 'm-2', 'contact_id': 'c-1', 'api_key': 'leak'},
    });

    expect(result['accepted'], isFalse);
    expect(result['reason'], 'secret_field_not_allowed');
  });

  test('non-string id is rejected to prevent primary key bypass', () async {
    final result = await PushApplier(dbService: dbService).apply({
      'table': 'messages',
      'operation': 'insert',
      'row': {'id': 12345, 'contact_id': 'c-1', 'role': 'user', 'content': 'x'},
    });

    expect(result['accepted'], isTrue);
    expect(result['applied'], isFalse);
    expect(result['reason'], 'invalid_id');
  });

  test('foreign key failure returns applied false', () async {
    final result = await PushApplier(dbService: dbService).apply({
      'table': 'messages',
      'operation': 'insert',
      'row': {
        'id': 'm-3',
        'contact_id': 'missing-contact',
        'role': 'user',
        'content': 'orphan',
      },
    });

    expect(result['accepted'], isTrue);
    expect(result['applied'], isFalse);
    expect(result['reason'], contains('apply_failed'));
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
