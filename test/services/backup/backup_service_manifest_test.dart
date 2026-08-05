import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/backup/backup_service.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/migrations/migration_v7.dart';
import 'package:soultalk/services/database/migrations/migration_v8.dart';
import 'package:soultalk/services/database/migrations/migration_v9.dart';
import 'package:soultalk/services/database/migrations/migration_v10.dart';
import 'package:soultalk/services/database/migrations/migration_v11.dart';

void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late BackupService service;
  var rebuildCount = 0;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('backup_manifest_test_');
    paths = AppPaths.fromRootForTesting(root);
    await paths.ensureInitialized();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createCoreTables(db);
    await migrateV7(db);
    await migrateV8(db);
    await migrateV9(db);
    await migrateV10(db);
    await migrateV11(db);
    rebuildCount = 0;
    service = BackupService(
      dbService: _TestDatabaseService(db),
      createAppPaths: () async => paths,
      rebuildIndexes: () async => rebuildCount++,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('exports manifest file hashes sizes and mtimes', () async {
    await File(
      '${paths.attachments.path}/chat/a.txt',
    ).create(recursive: true).then((file) => file.writeAsString('hello'));

    final zipPath = await service.exportToZip(
      sections: {BackupSection.attachments},
      targetDir: root.path,
    );

    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final manifest =
        jsonDecode(
              utf8.decode(
                archive.findFile('manifest.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(manifest['version'], '1.1');
    final files = (manifest['files'] as List).cast<Map>();
    final entry = files.singleWhere(
      (file) => file['archive_path'] == 'soultalk/attachments/chat/a.txt',
    );
    final archivedFile = archive.findFile(entry['archive_path'] as String)!;
    final bytes = archivedFile.content as List<int>;
    expect(entry['size'], bytes.length);
    expect(entry['sha256'], sha256.convert(bytes).toString());
    expect(entry['mtime'], isA<int>());
  });

  test('rejects tampered manifest file before restoring', () async {
    await File(
      '${paths.attachments.path}/chat/a.txt',
    ).create(recursive: true).then((file) => file.writeAsString('hello'));
    final zipPath = await service.exportToZip(
      sections: {BackupSection.attachments},
      targetDir: root.path,
    );
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final tampered = Archive();
    for (final file in archive.files) {
      if (file.name == 'soultalk/attachments/chat/a.txt') {
        final bytes = utf8.encode('tampered');
        tampered.addFile(ArchiveFile(file.name, bytes.length, bytes));
      } else if (file.isFile) {
        final bytes = file.content as List<int>;
        tampered.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }
    }
    final tamperedPath = '${root.path}/tampered.zip';
    await File(tamperedPath).writeAsBytes(ZipEncoder().encode(tampered));

    await File('${paths.attachments.path}/chat/a.txt').delete();
    final imported = await service.importFromZip(
      zipPath: tamperedPath,
      sections: {BackupSection.attachments},
    );

    expect(imported, isFalse);
    expect(
      await File('${paths.attachments.path}/chat/a.txt').exists(),
      isFalse,
    );
    expect(rebuildCount, 0);
  });

  test('rejects path traversal entries', () async {
    final payload = utf8.encode('evil');
    final manifest = {
      'version': '1.1',
      'app': 'soultalk',
      'sections': ['attachments'],
      'files': [
        {
          'archive_path': 'soultalk/attachments/../evil.txt',
          'domain': 'attachments',
          'sha256': sha256.convert(payload).toString(),
          'size': payload.length,
          'mtime': 1,
        },
      ],
    };
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode(manifest)).length,
          utf8.encode(jsonEncode(manifest)),
        ),
      )
      ..addFile(
        ArchiveFile(
          'soultalk/attachments/../evil.txt',
          payload.length,
          payload,
        ),
      );
    final zipPath = '${root.path}/evil.zip';
    await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

    final imported = await service.importFromZip(
      zipPath: zipPath,
      sections: {BackupSection.attachments},
    );

    expect(imported, isFalse);
    expect(await File('${root.path}/soultalk/evil.txt').exists(), isFalse);
  });

  test('creates restore point and rebuilds indexes after restore', () async {
    await File(
      '${paths.attachments.path}/chat/a.txt',
    ).create(recursive: true).then((file) => file.writeAsString('hello'));
    final zipPath = await service.exportToZip(
      sections: {BackupSection.attachments},
      targetDir: root.path,
    );
    await File('${paths.attachments.path}/chat/a.txt').delete();

    final imported = await service.importFromZip(
      zipPath: zipPath,
      sections: {BackupSection.attachments},
    );

    expect(imported, isTrue);
    expect(await File('${paths.attachments.path}/chat/a.txt').exists(), isTrue);
    expect(rebuildCount, 1);
    final restorePoints =
        await Directory('${paths.soultalk.path}/restore_points')
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.zip'))
            .toList();
    expect(restorePoints, isNotEmpty);
  });

  test('rolls back files when restore placement fails mid-way', () async {
    // 目标目录已有旧文件
    await File('${paths.attachments.path}/chat/a.txt')
        .create(recursive: true)
        .then((file) => file.writeAsString('old-a'));
    await File('${paths.attachments.path}/chat/b.txt')
        .create(recursive: true)
        .then((file) => file.writeAsString('old-b'));

    final zipPath = await service.exportToZip(
      sections: {BackupSection.attachments},
      targetDir: root.path,
    );

    // 用文件锁模拟落位阶段中途失败（Windows 上被打开的文件无法 rename）
    final handle = await File('${paths.attachments.path}/chat/b.txt').open();
    try {
      final imported = await service.importFromZip(
        zipPath: zipPath,
        sections: {BackupSection.attachments},
      );
      expect(imported, isFalse, reason: '落位失败必须整体失败');
    } finally {
      await handle.close();
    }

    // 回滚后目标目录保持恢复前原样，不留下半恢复状态
    expect(
      await File('${paths.attachments.path}/chat/a.txt').readAsString(),
      'old-a',
    );
    expect(
      await File('${paths.attachments.path}/chat/b.txt').readAsString(),
      'old-b',
    );
    expect(
      await Directory('${paths.attachments.path}.staging').exists(),
      isFalse,
      reason: 'staging 目录必须清理',
    );
    expect(
      await Directory('${paths.attachments.path}.backup').exists(),
      isFalse,
      reason: 'backup 目录必须清理',
    );
    expect(rebuildCount, 0, reason: '失败恢复不得重建索引');
  });

  test('backups and restores attachment_index with rebuild fallback', () async {
    // 文件名遵循 {uuid}-{originalName} 约定（uuid 固定 36 字符），
    // 恢复后 rebuildFromDirectory 才能从文件系统解析回索引。
    const uuid = '123e4567-e89b-12d3-a456-426614174000';
    final content = utf8.encode('hello');
    await File('${paths.attachments.path}/chat/$uuid-a.txt')
        .create(recursive: true)
        .then((file) => file.writeAsBytes(content));
    await db.insert('attachment_index', {
      'id': uuid,
      'chat_id': 'chat',
      'message_id': 'msg-1',
      'original_name': 'a.txt',
      'mime_type': 'text/plain',
      'relative_path': 'soultalk/attachments/chat/$uuid-a.txt',
      'sha256': sha256.convert(content).toString(),
      'size': content.length,
      'created_at': '2026-01-01T00:00:00.000',
    });

    final zipPath = await service.exportToZip(
      sections: {BackupSection.attachmentIndex, BackupSection.attachments},
      targetDir: root.path,
    );

    // 清空本地索引与文件后恢复
    await db.delete('attachment_index');
    await File('${paths.attachments.path}/chat/$uuid-a.txt').delete();

    final imported = await service.importFromZip(
      zipPath: zipPath,
      sections: {BackupSection.attachmentIndex, BackupSection.attachments},
    );

    expect(imported, isTrue);
    // 索引随备份写回；随后以文件系统为权威重建兜底
    expect(rebuildCount, 1, reason: '恢复 attachmentIndex 后必须重建索引兜底');
    final rows = await db.query('attachment_index');
    expect(rows, hasLength(1));
    expect(rows.single['sha256'], sha256.convert(content).toString());
    expect(rows.single['original_name'], 'a.txt');
    expect(
      await File('${paths.attachments.path}/chat/$uuid-a.txt').exists(),
      isTrue,
    );
  });
}

Future<void> _createCoreTables(Database db) async {
  await db.execute('''
    CREATE TABLE api_configs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      provider TEXT NOT NULL DEFAULT 'openai',
      base_url TEXT NOT NULL,
      api_key TEXT NOT NULL,
      model TEXT NOT NULL,
      max_tokens INTEGER NOT NULL DEFAULT 4096,
      temperature REAL NOT NULL DEFAULT 0.8,
      stream_enabled INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      avatar TEXT,
      description TEXT NOT NULL DEFAULT '',
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
  await db.execute('''
    CREATE TABLE moments (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      content TEXT NOT NULL,
      image_url TEXT,
      likes TEXT NOT NULL DEFAULT '[]',
      comments TEXT NOT NULL DEFAULT '[]',
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE chat_presets (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      segments TEXT NOT NULL DEFAULT '[]',
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE regex_scripts (
      id TEXT PRIMARY KEY,
      script_name TEXT NOT NULL,
      find_regex TEXT NOT NULL,
      replace_string TEXT NOT NULL DEFAULT '',
      trim_strings TEXT NOT NULL DEFAULT '[]',
      placement TEXT NOT NULL DEFAULT '[]',
      disabled INTEGER NOT NULL DEFAULT 0,
      markdown_only INTEGER NOT NULL DEFAULT 0,
      prompt_only INTEGER NOT NULL DEFAULT 0,
      run_on_edit INTEGER NOT NULL DEFAULT 0,
      substitute_regex INTEGER NOT NULL DEFAULT 0,
      min_depth INTEGER,
      max_depth INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE memory_entries (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '基本信息',
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE memory_states (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      slot_name TEXT NOT NULL,
      slot_value TEXT NOT NULL DEFAULT '',
      slot_type TEXT NOT NULL DEFAULT 'text',
      status TEXT NOT NULL DEFAULT 'active',
      confidence REAL NOT NULL DEFAULT 0.5,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE memory_cards (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      content TEXT NOT NULL,
      card_type TEXT NOT NULL DEFAULT 'fact',
      importance REAL NOT NULL DEFAULT 0.5,
      confidence REAL NOT NULL DEFAULT 0.5,
      scope TEXT NOT NULL DEFAULT 'local',
      tags TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      reviewed_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE cart_items (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      price REAL NOT NULL DEFAULT 0,
      quantity INTEGER NOT NULL DEFAULT 1,
      shop TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE wallet_transactions (
      id TEXT PRIMARY KEY,
      amount REAL NOT NULL DEFAULT 0,
      type TEXT NOT NULL DEFAULT 'spend',
      description TEXT NOT NULL DEFAULT '',
      contact_id TEXT,
      contact_name TEXT,
      created_at TEXT NOT NULL
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
