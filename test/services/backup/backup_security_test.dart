import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/backup/backup_service.dart';
import 'package:soultalk/services/database/database_service.dart';

void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late BackupService service;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('backup_security_test_');
    paths = AppPaths.fromRootForTesting(root);
    await paths.ensureInitialized();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createTables(db);
    service = BackupService(
      dbService: _TestDatabaseService(db),
      createAppPaths: () async => paths,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('export excludes api_key from api_configs', () async {
    await db.insert('api_configs', {
      'id': 'cfg-1',
      'name': 'main',
      'provider': 'openai',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'sk-secret-123',
      'model': 'gpt-4o-mini',
      'max_tokens': 4096,
      'temperature': 0.8,
      'stream_enabled': 1,
    });

    final zipPath = await service.exportToZip(
      sections: {BackupSection.apiConfigs},
      targetDir: root.path,
    );
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final rows =
        jsonDecode(
              utf8.decode(
                archive.findFile('api/api_configs.json')!.content as List<int>,
              ),
            )
            as List;
    expect(rows, isNotEmpty);
    expect((rows.single as Map).containsKey('api_key'), isFalse);
    expect(jsonEncode(rows), isNot(contains('sk-secret-123')));
  });

  test('export excludes sensitive SharedPreferences keys', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_webdav_password', 'wpass');
    await prefs.setString('auto_backup_s3_secret_key', 's3secret');
    await prefs.setString('auto_backup_internal_key', 'internal');
    await prefs.setString('voice_tts_api_key', 'tts-key');
    await prefs.setString('lansync_device_key', 'device-key');
    await prefs.setString('normal_setting', 'keep-me');

    final zipPath = await service.exportToZip(
      sections: {BackupSection.settings},
      targetDir: root.path,
    );
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final settings =
        jsonDecode(
              utf8.decode(
                archive.findFile('settings/settings.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(settings.containsKey('normal_setting'), isTrue);
    expect(settings.containsKey('auto_backup_webdav_password'), isFalse);
    expect(settings.containsKey('auto_backup_s3_secret_key'), isFalse);
    expect(settings.containsKey('auto_backup_internal_key'), isFalse);
    expect(settings.containsKey('voice_tts_api_key'), isFalse);
    expect(settings.containsKey('lansync_device_key'), isFalse);
    expect(jsonEncode(settings), isNot(contains('wpass')));
    expect(jsonEncode(settings), isNot(contains('s3secret')));
  });

  test('restore preserves existing local api_key (upsert, not replace)',
      () async {
    // 本地已有配置（含 key）
    await db.insert('api_configs', {
      'id': 'cfg-1',
      'name': 'local',
      'provider': 'openai',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'local-key',
      'model': 'gpt-4o-mini',
      'max_tokens': 4096,
      'temperature': 0.8,
      'stream_enabled': 1,
    });
    // 备份另一份（无 api_key）
    final zipPath = await service.exportToZip(
      sections: {BackupSection.apiConfigs},
      targetDir: root.path,
    );

    await db.update(
      'api_configs',
      {'name': 'to-be-overwritten'},
      where: 'id = ?',
      whereArgs: ['cfg-1'],
    );
    final imported = await service.importFromZip(
      zipPath: zipPath,
      sections: {BackupSection.apiConfigs},
    );

    expect(imported, isTrue);
    final rows = await db.query('api_configs', where: 'id = ?', whereArgs: ['cfg-1']);
    expect(rows.single['api_key'], 'local-key'); // 保留本地 key
    expect(rows.single['name'], 'local'); // 其他字段按备份覆盖
  });

  test('restore does not cascade-delete child rows when contact id conflicts',
      () async {
    // contacts 与 messages 带外键级联；恢复同 id 联系人时
    // 子表（messages）必须保留（REPLACE 会先 DELETE 再 INSERT）
    await db.rawQuery('PRAGMA foreign_keys=ON');
    await db.insert('contacts', {
      'id': 'contact-1',
      'name': 'Alice',
      'description': '',
      'system_prompt': '',
    });
    await db.insert('messages', {
      'id': 'msg-1',
      'contact_id': 'contact-1',
      'role': 'user',
      'content': 'hello',
      'created_at': '2026-01-01T00:00:00',
    });
    await db.insert('messages', {
      'id': 'msg-2',
      'contact_id': 'contact-1',
      'role': 'assistant',
      'content': 'hi',
      'created_at': '2026-01-01T00:01:00',
    });

    final zipPath = await service.exportToZip(
      sections: {BackupSection.contacts, BackupSection.messages},
      targetDir: root.path,
    );

    // 修改本地联系人（备份后新增/变更）再恢复
    await db.update(
      'contacts',
      {'name': 'Alice (edited)'},
      where: 'id = ?',
      whereArgs: ['contact-1'],
    );
    final imported = await service.importFromZip(
      zipPath: zipPath,
      sections: {BackupSection.contacts, BackupSection.messages},
    );

    expect(imported, isTrue);
    final contactRows = await db.query('contacts', where: 'id = ?', whereArgs: ['contact-1']);
    expect(contactRows, hasLength(1));
    expect(contactRows.single['name'], 'Alice');
    final msgCount = await db.rawQuery('SELECT COUNT(*) AS c FROM messages');
    expect(msgCount.single['c'], 2, reason: '恢复联系人不得级联删除其消息');
  });

  test('forceEncrypt without password rejects plaintext export', () async {
    expect(
      () => service.exportToZip(
        sections: {BackupSection.settings},
        targetDir: root.path,
        forceEncrypt: true,
      ),
      throwsArgumentError,
    );
    // 不得留下明文 zip
    final leftovers = root
        .listSync()
        .where((e) => e.path.endsWith('.zip'))
        .toList();
    expect(leftovers, isEmpty);
  });

  test('forceEncrypt with password produces encrypted archive', () async {
    final zipPath = await service.exportToZip(
      sections: {BackupSection.settings},
      targetDir: root.path,
      password: 'cloud-pass-123',
      forceEncrypt: true,
    );
    expect(zipPath.endsWith('.enc.zip'), isTrue);
    final bytes = await File(zipPath).readAsBytes();
    // SG1 魔数 = AES-256-GCM + PBKDF2 加密格式
    expect(utf8.decode(bytes.sublist(0, 3)), 'SG1');
  });
}

Future<void> _createTables(Database db) async {
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
      created_at TEXT,
      FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
    )
  ''');
  // 恢复点导出全量 sections 所需的最小表集合
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
    CREATE TABLE cart_items (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      price REAL NOT NULL DEFAULT 0,
      quantity INTEGER NOT NULL DEFAULT 1,
      shop TEXT
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
  await db.execute('''
    CREATE TABLE scheduler_jobs (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      target_id TEXT NOT NULL,
      run_after INTEGER NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending',
      payload TEXT NOT NULL DEFAULT '{}',
      last_error TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE proactive_rules (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 1,
      min_hours INTEGER NOT NULL DEFAULT 2,
      probability REAL NOT NULL DEFAULT 0.3,
      last_triggered_at TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE proactive_events (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL,
      rule_id TEXT,
      event_type TEXT NOT NULL,
      status TEXT NOT NULL,
      payload TEXT,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE friend_circle_rules (
      id TEXT PRIMARY KEY,
      contact_id TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 1,
      interval_hours INTEGER NOT NULL DEFAULT 24,
      last_posted_at TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE pc_deletions (
      id TEXT PRIMARY KEY,
      table_name TEXT NOT NULL,
      row_id TEXT NOT NULL,
      deleted_at INTEGER NOT NULL
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
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
