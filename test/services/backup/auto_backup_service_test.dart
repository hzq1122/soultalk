import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/backup/auto_backup_service.dart';
import 'package:soultalk/services/database/database_service.dart';

void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late AutoBackupService service;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('auto_backup_test_');
    paths = AppPaths.fromRootForTesting(root);
    await paths.ensureInitialized();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createTables(db);
    service = AutoBackupService.forTesting(
      dbService: _TestDatabaseService(db),
      createAppPaths: () async => paths,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('fingerprint changes when any table data changes', () async {
    final prefs = await SharedPreferences.getInstance();
    final before = await service.computeFingerprint(db, prefs);

    await db.insert('messages', {
      'id': 'm1',
      'contact_id': 'c1',
      'role': 'user',
      'content': 'hi',
      'type': 'text',
      'created_at': '2026-01-01T00:00:00.000',
    });

    final after = await service.computeFingerprint(db, prefs);
    expect(after, isNot(before));
  });

  test('fingerprint detects in-place edits (updated_at refresh)', () async {
    final prefs = await SharedPreferences.getInstance();
    await db.insert('messages', {
      'id': 'm1',
      'contact_id': 'c1',
      'role': 'user',
      'content': 'original',
      'type': 'text',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    final before = await service.computeFingerprint(db, prefs);

    // 原地编辑：created_at 不变，仅内容与 updated_at 变化
    await db.update(
      'messages',
      {'content': 'edited', 'updated_at': '2026-01-02T00:00:00.000'},
      where: 'id = ?',
      whereArgs: ['m1'],
    );

    final after = await service.computeFingerprint(db, prefs);
    // 旧指纹（count + max(created_at)）检测不到该修改，必须变化
    expect(after, isNot(before));
  });

  test('fingerprint changes when non-sensitive settings change', () async {
    final prefs = await SharedPreferences.getInstance();
    final before = await service.computeFingerprint(db, prefs);

    await prefs.setString('theme_color', 'dark');
    final after = await service.computeFingerprint(db, prefs);
    expect(after, isNot(before));
  });

  test(
    'fingerprint changes when attachments or st_compat files change',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final before = await service.computeFingerprint(db, prefs);

      await File(
        '${paths.attachments.path}/chat/x.txt',
      ).create(recursive: true).then((f) => f.writeAsString('hello'));
      final afterAttach = await service.computeFingerprint(db, prefs);
      expect(afterAttach, isNot(before));

      await File(
        '${paths.stCompat.path}/characters/a.json',
      ).create(recursive: true).then((f) => f.writeAsString('{}'));
      final afterCompat = await service.computeFingerprint(db, prefs);
      expect(afterCompat, isNot(afterAttach));
    },
  );

  test('fingerprint ignores auto_backup state keys and credentials', () async {
    final prefs = await SharedPreferences.getInstance();
    final before = await service.computeFingerprint(db, prefs);

    await prefs.setString('auto_backup_last_hash', 'whatever');
    await prefs.setString('auto_backup_last_time', '2026-01-01T00:00:00');
    await prefs.setString('auto_backup_internal_key', 'secret');
    await prefs.setString('auto_backup_webdav_password', 'wpass');
    await prefs.setString('auto_backup_s3_secret_key', 's3secret');
    await prefs.setString('lansync_device_key', 'device-key');

    final after = await service.computeFingerprint(db, prefs);
    expect(after, before, reason: '状态与凭据 key 变化不得触发自动备份');
  });

  test('fingerprint ignores scheduler_run_log diagnostics', () async {
    final prefs = await SharedPreferences.getInstance();
    final before = await service.computeFingerprint(db, prefs);

    await db.insert('scheduler_run_log', {
      'id': 'log1',
      'job_id': 'job1',
      'status': 'success',
      'started_at': '2026-01-01T00:00:00.000',
      'finished_at': '2026-01-01T00:00:01.000',
    });

    final after = await service.computeFingerprint(db, prefs);
    expect(after, before);
  });
}

Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
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
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE attachment_index (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      original_name TEXT NOT NULL,
      relative_path TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      size INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE scheduler_jobs (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      target_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE scheduler_run_log (
      id TEXT PRIMARY KEY,
      job_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'success',
      started_at TEXT NOT NULL,
      finished_at TEXT
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
