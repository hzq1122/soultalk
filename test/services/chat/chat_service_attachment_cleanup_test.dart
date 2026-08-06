import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/chat/chat_service.dart';
import 'package:soultalk/services/database/attachment_index_dao.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v14.dart';
import 'package:soultalk/services/database/migrations/migration_v8.dart';

/// 编辑消息（deleteMessagesAfter）后清理后续消息附件：
/// attachment_index 记录与磁盘文件都必须删除，不留孤儿文件。
void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late ChatService service;

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('chat_attach_test_');
    paths = AppPaths.fromRootForTesting(root);
    await paths.ensureInitialized();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createTables(db);
    await migrateV14(db);
    service = ChatService(
      dbService: _TestDatabaseService(db),
      createAppPaths: () async => paths,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('deleteMessagesAfter removes attachments of deleted messages', () async {
    // 联系人
    await db.insert('contacts', {
      'id': 'c-1',
      'name': 'Alice',
      'description': '',
      'system_prompt': '',
    });
    // 被编辑的用户消息
    await db.insert('messages', {
      'id': 'edit-msg',
      'contact_id': 'c-1',
      'role': 'user',
      'content': 'edited question',
      'created_at': '2026-01-01T10:00:00.000',
      'updated_at': '2026-01-01T10:00:00.000',
    });
    // 其后的 AI 回复（带附件）
    await db.insert('messages', {
      'id': 'ai-msg',
      'contact_id': 'c-1',
      'role': 'assistant',
      'content': 'reply with file',
      'created_at': '2026-01-01T10:01:00.000',
      'updated_at': '2026-01-01T10:01:00.000',
      'metadata': jsonEncode({
        'attachment': {'id': 'att-1'},
      }),
    });
    // 其后的用户附件消息
    await db.insert('messages', {
      'id': 'file-msg',
      'contact_id': 'c-1',
      'role': 'user',
      'content': 'soultalk/attachments/c-1/uuid12345-report.pdf',
      'type': 'file',
      'created_at': '2026-01-01T10:02:00.000',
      'updated_at': '2026-01-01T10:02:00.000',
    });

    // 附件索引 + 磁盘文件（att-1 由 metadata 关联；att-2 由 content 回退关联）
    final dao = AttachmentIndexDao(_TestDatabaseService(db));
    await dao.upsert(
      AttachmentIndexRecord(
        id: 'att-1',
        chatId: 'c-1',
        messageId: 'ai-msg',
        originalName: 'a.pdf',
        mimeType: 'application/pdf',
        relativePath: 'soultalk/attachments/c-1/uuid12345-a.pdf',
        sha256: 'x',
        size: 1,
        createdAt: 1,
      ),
    );
    await dao.upsert(
      AttachmentIndexRecord(
        id: 'att-2',
        chatId: 'c-1',
        messageId: 'file-msg',
        originalName: 'report.pdf',
        mimeType: 'application/pdf',
        relativePath: 'soultalk/attachments/c-1/uuid12345-report.pdf',
        sha256: 'x',
        size: 1,
        createdAt: 1,
      ),
    );
    final file1 = File(
      p.join(paths.root.path, 'soultalk/attachments/c-1/uuid12345-a.pdf'),
    );
    final file2 = File(
      p.join(paths.root.path, 'soultalk/attachments/c-1/uuid12345-report.pdf'),
    );
    await file1.create(recursive: true);
    await file2.create(recursive: true);

    await service.deleteMessagesAfter('c-1', 'edit-msg');

    // 后续消息已删除
    final rows = await db.query('messages');
    expect(rows.map((r) => r['id']), ['edit-msg']);
    // 附件索引已删除
    expect(await dao.getById('att-1'), isNull);
    expect(await dao.getById('att-2'), isNull);
    // 磁盘文件已删除
    expect(await file1.exists(), isFalse);
    expect(await file2.exists(), isFalse);
  });

  test('deleteMessagesAfter keeps attachments of the edited message', () async {
    await db.insert('contacts', {
      'id': 'c-1',
      'name': 'Alice',
      'description': '',
      'system_prompt': '',
    });
    await db.insert('messages', {
      'id': 'edit-msg',
      'contact_id': 'c-1',
      'role': 'user',
      'content': 'keep me',
      'created_at': '2026-01-01T10:00:00.000',
      'updated_at': '2026-01-01T10:00:00.000',
    });
    final dao = AttachmentIndexDao(_TestDatabaseService(db));
    await dao.upsert(
      AttachmentIndexRecord(
        id: 'att-keep',
        chatId: 'c-1',
        messageId: 'edit-msg',
        originalName: 'keep.pdf',
        mimeType: 'application/pdf',
        relativePath: 'soultalk/attachments/c-1/uuid12345-keep.pdf',
        sha256: 'x',
        size: 1,
        createdAt: 1,
      ),
    );
    final file = File(
      p.join(paths.root.path, 'soultalk/attachments/c-1/uuid12345-keep.pdf'),
    );
    await file.create(recursive: true);

    await service.deleteMessagesAfter('c-1', 'edit-msg');

    expect(await dao.getById('att-keep'), isNotNull);
    expect(await file.exists(), isTrue);
  });
}

Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      avatar TEXT,
      api_config_id TEXT,
      system_prompt TEXT NOT NULL DEFAULT '',
      character_card_json TEXT,
      tags TEXT NOT NULL DEFAULT '[]',
      pinned INTEGER NOT NULL DEFAULT 0,
      unread_count INTEGER NOT NULL DEFAULT 0,
      last_message TEXT,
      last_message_at TEXT,
      proactive_enabled INTEGER NOT NULL DEFAULT 1,
      last_proactive_at TEXT,
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
  await migrateV8(db);
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
