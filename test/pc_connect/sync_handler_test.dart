import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/pc_connect/sync_handler.dart';
import 'package:soultalk/services/database/database_service.dart';

/// SyncHandler 冲突解决链路测试（keep_mobile / keep_pc / manual_edit）。
void main() {
  late Database db;
  late DatabaseService dbService;
  late SyncHandler handler;

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
        token_count INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        created_at TEXT
      )
    ''');
    await db.insert('messages', {
      'id': 'm-1',
      'contact_id': 'c-1',
      'role': 'assistant',
      'content': 'mobile version',
    });
    dbService = _TestDatabaseService(db);
    handler = SyncHandler(dbService: dbService);
  });

  tearDown(() async {
    await db.close();
  });

  test('keep_mobile keeps mobile content unchanged', () async {
    await handler.applyResolutions([
      {'action': 'keep_mobile', 'messageId': 'm-1'},
    ]);

    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: ['m-1'],
    );
    expect(rows.single['content'], 'mobile version');
  });

  test('keep_pc replaces mobile content with pc version', () async {
    await handler.applyResolutions([
      {'action': 'keep_pc', 'messageId': 'm-1', 'content': 'pc version'},
    ]);

    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: ['m-1'],
    );
    expect(rows.single['content'], 'pc version');
  });

  test('manual_edit applies edited content', () async {
    await handler.applyResolutions([
      {
        'action': 'manual_edit',
        'messageId': 'm-1',
        'content': 'edited content',
      },
    ]);

    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: ['m-1'],
    );
    expect(rows.single['content'], 'edited content');
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
