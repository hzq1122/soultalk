import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/pc_connect/sync_handler.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v14.dart';

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
      is_failed INTEGER NOT NULL DEFAULT 0,
        token_count INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        created_at TEXT
      )
    ''');
    // v14 增加 updated_at：getSyncData/Merkle 依赖修改水位
    await migrateV14(db);
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

  test('getSyncData 按 updated_at 水位返回原地修改的行', () async {
    final oldTime = DateTime.now().subtract(const Duration(hours: 2));
    await db.update(
      'messages',
      {'updated_at': oldTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: ['m-1'],
    );

    // 水位在 oldTime 之后：不返回
    var data = await handler.getSyncData(
      since: oldTime.add(const Duration(minutes: 1)),
    );
    expect(data['messages'], isEmpty);

    // 原地修改（仅 content + updated_at，created_at 不变）
    await db.update(
      'messages',
      {
        'content': 'edited in place',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: ['m-1'],
    );

    // 水位在修改之前：修改行被重新拉取（旧链路 created_at > since 会漏掉）
    data = await handler.getSyncData(
      since: oldTime.subtract(const Duration(minutes: 1)),
    );
    final rows = data['messages'] as List;
    expect(rows, hasLength(1));
    expect((rows.single as Map)['content'], 'edited in place');
  });

  test('calculateMerkleRoot 确定性与修改敏感', () async {
    final before = await handler.calculateMerkleRoot();
    final again = await handler.calculateMerkleRoot();
    expect(before, again);

    // 原地修改（created_at 不变）必须改变 Merkle：
    // 旧实现按原始 DB 行（snake_case）编码，且新实现与 PC 端
    // camelCase mirror 规范化一致。
    await db.update(
      'messages',
      {'content': 'changed', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: ['m-1'],
    );
    final after = await handler.calculateMerkleRoot();
    expect(after, isNot(before));
  });

  test('Merkle 行编码与 PC mirror 规范化一致（camelCase + key 排序）', () async {
    final root = await handler.calculateMerkleRoot();
    // 与 PC 端规则做交叉验证：用同一行数据按 camelCase + key 排序
    // 手工计算期望哈希，两端应一致。
    final rows = await db.query('messages');
    final row = (rows.single as Map).cast<String, dynamic>();
    final camel = <String, dynamic>{
      'contactId': row['contact_id'],
      'content': row['content'],
      // 手机端与 PC mirror 的映射表把 created_at → timestamp
      'timestamp': row['created_at'],
      'id': row['id'],
      'isFailed': row['is_failed'],
      'isStreaming': row['is_streaming'],
      'metadata': row['metadata'],
      'role': row['role'],
      'tokenCount': row['token_count'],
      'type': row['type'],
      'updatedAt': row['updated_at'],
    };
    final sorted = Map<String, dynamic>.fromEntries(
      camel.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final expected = sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
    expect(root, expected);
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
