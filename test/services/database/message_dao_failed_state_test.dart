import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/models/message.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/message_dao.dart';
import 'package:soultalk/services/database/migrations/migration_v12.dart';
import 'package:soultalk/services/database/migrations/migration_v14.dart';

void main() {
  late Database db;
  late MessageDao dao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createV11MessagesTable(db);
    await migrateV12(db);
    // v14 为 messages 增加 updated_at：MessageDao 现在写入该列
    await migrateV14(db);
    dao = MessageDao(_TestDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'migration v12 adds is_failed column and persists failed state',
    () async {
      final msg = await dao.insert(
        Message(
          id: '',
          contactId: 'c-1',
          role: MessageRole.assistant,
          content: 'partial',
          createdAt: DateTime.now(),
        ),
      );

      await dao.updateFailed(msg.id, true);

      final loaded = await dao.getById(msg.id);
      expect(loaded, isNotNull);
      expect(loaded!.isFailed, isTrue);
      expect(loaded.isStreaming, isFalse);
      expect(loaded.content, 'partial');
    },
  );

  test('failed flag survives re-query and defaults to false', () async {
    final msg = await dao.insert(
      Message(
        id: '',
        contactId: 'c-1',
        role: MessageRole.user,
        content: 'hi',
        createdAt: DateTime.now(),
      ),
    );
    final loaded = await dao.getById(msg.id);
    expect(loaded!.isFailed, isFalse);
  });
}

Future<void> _createV11MessagesTable(Database db) async {
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
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
