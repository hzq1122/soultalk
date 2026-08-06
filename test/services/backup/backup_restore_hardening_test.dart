import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/services/backup/backup_service.dart';
import 'package:soultalk/services/database/database_service.dart';

/// 备份恢复加固测试：
/// - zip bomb：decodeBytes 之前拒绝超限备份（不占内存）；
/// - manifest 白名单：ZIP 中未声明的额外文件拒绝恢复（防注入）；
/// - symlink 防护：目标路径祖先为链接时拒绝写入（Windows 无权限时跳过）。
void main() {
  late Directory root;
  late AppPaths paths;
  late Database db;
  late BackupService service;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('backup_hardening_test_');
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

  test('zip bomb rejected before decode (no memory blow-up)', () async {
    // 手工构造 STORE 模式 zip：两个文件各声明 3 GiB 未压缩大小
    // （总计 6 GiB > 4 GiB 上限），真实内容只有几个字节。
    // precheck 只读 central directory，不展开内容即拒绝。
    final bytes = _buildFakeOversizedZip();
    final zipPath = p.join(root.path, 'bomb.zip');
    await File(zipPath).writeAsBytes(bytes);

    final report = await service.importFromZipWithReport(
      zipPath: zipPath,
      sections: BackupSection.values.toSet(),
    );

    expect(report.success, isFalse);
    expect(report.error, contains('备份文件过大'));
  });

  test('invalid zip bytes rejected', () async {
    final zipPath = p.join(root.path, 'not_a_zip.zip');
    await File(zipPath).writeAsBytes(List.filled(100, 7));

    final report = await service.importFromZipWithReport(
      zipPath: zipPath,
      sections: BackupSection.values.toSet(),
    );

    expect(report.success, isFalse);
    expect(report.error, contains('不是有效的 ZIP'));
  });

  test('undeclared files in zip are rejected (manifest whitelist)', () async {
    // 先造一份带 st_compat 文件的合法备份
    final compatDir = paths.stCompat;
    await Directory(
      p.join(compatDir.path, 'characters'),
    ).create(recursive: true);
    await File(
      p.join(compatDir.path, 'characters', 'Alice.json'),
    ).writeAsString('{"spec":"chara_card_v2"}');

    final zipPath = await service.exportToZip(
      sections: {BackupSection.compatFiles},
      targetDir: root.path,
    );

    // 注入额外文件（不更新 manifest）
    final injected = await _injectFileIntoZip(
      zipPath,
      'st_compat/characters/Evil.json',
      '{"evil":true}',
    );
    final evilZip = p.join(root.path, 'injected.zip');
    await File(evilZip).writeAsBytes(injected);

    final report = await service.importFromZipWithReport(
      zipPath: evilZip,
      sections: {BackupSection.compatFiles},
    );

    expect(report.success, isFalse);
    expect(report.error, contains('Undeclared archive file'));
    // 目标目录不得出现注入文件
    expect(
      await File(p.join(compatDir.path, 'characters', 'Evil.json')).exists(),
      isFalse,
    );
  });

  test('symlink ancestor blocks restore write', () async {
    // Windows 无开发者模式/管理员权限时无法创建 symlink，跳过
    final outside = Directory(p.join(root.path, 'outside'));
    await outside.create();
    final link = Link(p.join(paths.attachments.path, 'linked'));
    try {
      await link.create(outside.path);
    } on FileSystemException {
      markTestSkipped('no symlink permission on this host');
      return;
    }

    // 构造指向 linked/ 下文件的备份
    final subDir = p.join(paths.attachments.path, 'linked', 'sub');
    await Directory(subDir).create(recursive: true);
    await File(p.join(subDir, 'a.txt')).writeAsString('data');
    final zipPath = await service.exportToZip(
      sections: {BackupSection.attachments},
      targetDir: root.path,
    );
    // 删除链接，恢复时目标路径祖先成为 link
    await link.delete();

    final report = await service.importFromZipWithReport(
      zipPath: zipPath,
      sections: {BackupSection.attachments},
    );

    expect(report.success, isFalse);
    expect(report.error, contains('Symlink in restore path'));
    // 外部目录不得被写入
    expect(await File(p.join(outside.path, 'sub', 'a.txt')).exists(), isFalse);
  });
}

/// 构造两个各声明 3 GiB 未压缩大小的 STORE zip（真实内容很小）。
List<int> _buildFakeOversizedZip() {
  final out = BytesBuilder();
  final names = ['big1.bin', 'big2.bin'];
  const huge = 0xC0000000; // 3 GiB
  const store = 0; // compression method: STORE
  for (final name in names) {
    final nameBytes = utf8.encode(name);
    // Local file header
    out.add([0x50, 0x4B, 0x03, 0x04]);
    out.add(_u16(20)); // version needed
    out.add(_u16(0)); // flags
    out.add(_u16(store)); // method
    out.add(_u16(0)); // time
    out.add(_u16(0)); // date
    out.add(_u32(0)); // crc32 (unchecked by precheck)
    out.add(_u32(1)); // compressed size
    out.add(_u32(huge)); // uncompressed size (fake)
    out.add(_u16(nameBytes.length));
    out.add(_u16(0)); // extra len
    out.add(nameBytes);
    out.add([0x41]); // one byte of data
  }
  final cdStart = out.length;
  var cdSize = 0;
  for (final name in names) {
    final nameBytes = utf8.encode(name);
    out.add([0x50, 0x4B, 0x01, 0x02]);
    out.add(_u16(20)); // version made by
    out.add(_u16(20)); // version needed
    out.add(_u16(0)); // flags
    out.add(_u16(store)); // method
    out.add(_u16(0)); // time
    out.add(_u16(0)); // date
    out.add(_u32(0)); // crc32
    out.add(_u32(1)); // compressed size
    out.add(_u32(huge)); // uncompressed size (fake)
    out.add(_u16(nameBytes.length));
    out.add(_u16(0)); // extra len
    out.add(_u16(0)); // comment len
    out.add(_u16(0)); // disk number start
    out.add(_u16(0)); // internal attrs
    out.add(_u32(0)); // external attrs
    out.add(_u32(0)); // local header offset
    out.add(nameBytes);
    cdSize += 46 + nameBytes.length;
  }
  // EOCD
  out.add([0x50, 0x4B, 0x05, 0x06]);
  out.add(_u16(0)); // disk number
  out.add(_u16(0)); // cd start disk
  out.add(_u16(2)); // entries on this disk
  out.add(_u16(2)); // total entries
  out.add(_u32(cdSize));
  out.add(_u32(cdStart));
  out.add(_u16(0)); // comment len
  return out.toBytes();
}

/// 读取 zip 字节、注入额外文件、重新编码（manifest 保持不变）。
Future<List<int>> _injectFileIntoZip(
  String zipPath,
  String archivePath,
  String content,
) async {
  final bytes = await File(zipPath).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);
  archive.addFile(
    ArchiveFile(archivePath, content.length, utf8.encode(content)),
  );
  return ZipEncoder().encode(archive);
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> _u32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE contacts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      system_prompt TEXT NOT NULL DEFAULT '',
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
      token_count INTEGER NOT NULL DEFAULT 0,
      metadata TEXT,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE api_configs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      provider TEXT NOT NULL DEFAULT 'openai',
      base_url TEXT NOT NULL,
      api_key TEXT NOT NULL,
      model TEXT NOT NULL DEFAULT 'gpt-4o-mini',
      max_tokens INTEGER NOT NULL DEFAULT 4096,
      temperature REAL NOT NULL DEFAULT 0.8,
      stream_enabled INTEGER NOT NULL DEFAULT 1,
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
