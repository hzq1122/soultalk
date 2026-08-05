import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/database/contact_dao.dart';
import 'package:soultalk/services/database/database_service.dart';

void main() {
  late Database db;
  late ContactDao dao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '[]',
        pinned INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0,
        last_message TEXT,
        last_message_at TEXT,
        created_at TEXT,
        updated_at TEXT
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
        created_at TEXT
      )
    ''');
    dao = ContactDao(_TestDatabaseService(db));
    await db.insert('contacts', {
      'id': 'c-1',
      'name': 'Alice',
      'unread_count': 3,
      'last_message': 'old',
      'last_message_at': '2026-01-01T00:00:00.000',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertMsg(String id, String role, String content, String at) {
    return db.insert('messages', {
      'id': id,
      'contact_id': 'c-1',
      'role': role,
      'content': content,
      'type': 'text',
      'created_at': at,
    });
  }

  test('recompute picks the latest non-system message', () async {
    await insertMsg('m1', 'user', 'first', '2026-01-01T00:00:01.000');
    await insertMsg('m2', 'assistant', 'second', '2026-01-01T00:00:02.000');
    await insertMsg('m3', 'system', 'system note', '2026-01-01T00:00:03.000');

    await dao.recomputeLastMessage('c-1');

    final row = (await db.query('contacts', where: 'id = ?', whereArgs: ['c-1'])).single;
    expect(row['last_message'], 'second');
    expect(row['last_message_at'], '2026-01-01T00:00:02.000');
  });

  test('recompute clears last message and unread when chat is empty',
      () async {
    await insertMsg('m1', 'user', 'only', '2026-01-01T00:00:01.000');
    await db.delete('messages');
    // 模拟未读数残留
    await db.update('contacts', {'unread_count': 5}, where: 'id = ?', whereArgs: ['c-1']);

    await dao.recomputeLastMessage('c-1');

    final row = (await db.query('contacts', where: 'id = ?', whereArgs: ['c-1'])).single;
    expect(row['last_message'], isNull);
    expect(row['last_message_at'], isNull);
    expect(row['unread_count'], 0);
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
