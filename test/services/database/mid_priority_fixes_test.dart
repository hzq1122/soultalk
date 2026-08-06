import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/services/backup/cloud_storage.dart';
import 'package:soultalk/services/database/attachment_index_dao.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v14.dart';
import 'package:soultalk/services/database/migrations/migration_v15.dart';

void main() {
  group('migration_v15 created_at NOT NULL', () {
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await _createV14MessagesTable(db);
      await migrateV14(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'rebuilds table with NOT NULL created_at and backfills nulls',
      () async {
        // v14 遗留：created_at 为 NULL 的历史行
        await db.insert('messages', {
          'id': 'm-null-ts',
          'contact_id': 'c-1',
          'role': 'user',
          'content': 'legacy',
        });
        await db.insert('messages', {
          'id': 'm-ok',
          'contact_id': 'c-1',
          'role': 'assistant',
          'content': 'normal',
          'created_at': '2026-01-01T00:00:00.000',
          'updated_at': '2026-01-01T00:00:00.000',
        });

        await migrateV15(db);

        final cols = await db.rawQuery('PRAGMA table_info(messages)');
        final createdAt = cols.firstWhere((c) => c['name'] == 'created_at');
        expect(createdAt['notnull'], 1);

        final rows = await db.query('messages', orderBy: 'id ASC');
        expect(rows, hasLength(2));
        final legacy = rows.firstWhere((r) => r['id'] == 'm-null-ts');
        expect(legacy['created_at'], isNotNull, reason: 'null 时间戳已回填');
        // 数据完整保留
        expect(rows.any((r) => r['content'] == 'legacy'), isTrue);
        expect(rows.any((r) => r['content'] == 'normal'), isTrue);

        // 迁移后插入不再允许 NULL（NOT NULL 约束生效）
        expect(
          () => db.insert('messages', {
            'id': 'm-null-2',
            'contact_id': 'c-1',
            'role': 'user',
            'content': 'should fail',
          }),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test('idempotent: second run is a no-op', () async {
      await migrateV15(db);
      await migrateV15(db);
      final cols = await db.rawQuery('PRAGMA table_info(messages)');
      final createdAt = cols.firstWhere((c) => c['name'] == 'created_at');
      expect(createdAt['notnull'], 1);
    });
  });

  group('attachment index rebuild keeps message_id / mime_type', () {
    late Database db;
    late Directory root;

    setUp(() async {
      sqfliteFfiInit();
      root = await Directory.systemTemp.createTemp('attach_rebuild_test_');
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
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE attachment_index (
          id TEXT PRIMARY KEY,
          chat_id TEXT NOT NULL,
          message_id TEXT,
          original_name TEXT NOT NULL,
          mime_type TEXT,
          relative_path TEXT NOT NULL,
          sha256 TEXT NOT NULL,
          size INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test(
      'rebuild restores message_id and mime_type from message metadata',
      () async {
        final chatDir = Directory('${root.path}/c-1');
        await chatDir.create(recursive: true);
        final file = File(
          '${chatDir.path}/att-abc-123456789012345678901234-report.pdf',
        );
        await file.writeAsString('pdf bytes');
        // 文件名约定：36 字符 uuid + '-' + originalName
        final fixedName = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee-report.pdf';
        final fixed = File('${chatDir.path}/$fixedName');
        await file.rename(fixed.path);

        await db.insert('messages', {
          'id': 'msg-1',
          'contact_id': 'c-1',
          'role': 'user',
          'content': 'see attachment',
          'metadata':
              '{"attachment":{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",'
              '"name":"report.pdf","mime":"application/pdf",'
              '"relative_path":"soultalk/attachments/c-1/$fixedName",'
              '"size":9,"sha256":"x"}}',
        });

        final dao = AttachmentIndexDao(_TestDatabaseService(db));
        final count = await dao.rebuildFromDirectory(root);
        expect(count, 1);

        final record = await dao.getByRelativePath(
          'soultalk/attachments/c-1/$fixedName',
        );
        expect(record, isNotNull);
        // 关键断言：message_id 与 mime_type 从消息 metadata 恢复
        expect(record!.messageId, 'msg-1');
        expect(record.mimeType, 'application/pdf');
      },
    );
  });

  group('cloud storage scheme enforcement', () {
    test('https is allowed for webdav and s3', () {
      expect(
        () => assertSecureScheme('https://dav.example.com', 'WebDAV'),
        returnsNormally,
      );
      expect(
        () => assertSecureScheme('https://s3.example.com', 'S3'),
        returnsNormally,
      );
    });

    test('http to non-localhost is rejected (credentials leak)', () {
      expect(
        () => assertSecureScheme('http://dav.example.com', 'WebDAV'),
        throwsArgumentError,
      );
      expect(
        () => assertSecureScheme('http://s3.example.com', 'S3'),
        throwsArgumentError,
      );
    });

    test('http to localhost is allowed for local debugging', () {
      expect(
        () => assertSecureScheme('http://localhost:8080', 'WebDAV'),
        returnsNormally,
      );
      expect(
        () => assertSecureScheme('http://127.0.0.1:9000', 'S3'),
        returnsNormally,
      );
    });
  });
}

Future<void> _createV14MessagesTable(Database db) async {
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
      updated_at TEXT
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
