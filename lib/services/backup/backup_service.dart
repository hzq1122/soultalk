import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_paths.dart';
import '../database/attachment_index_dao.dart';
import '../database/database_service.dart';
import '../st_compat/compat_storage_bootstrap_service.dart';
import 'backup_encryption.dart';

enum BackupSection {
  apiConfigs,
  contacts,
  messages,
  moments,
  settings,
  presets,
  regexScripts,
  memoryEntries,
  schedulerJobs,
  proactiveRules,
  proactiveEvents,
  friendCircleRules,
  walletTransactions,
  cartItems,
  compatFiles,
  attachments,
  attachmentIndex,
}

extension BackupSectionLabel on BackupSection {
  String get label => switch (this) {
    BackupSection.apiConfigs => 'API 配置',
    BackupSection.contacts => '联系人',
    BackupSection.messages => '聊天记录',
    BackupSection.moments => '朋友圈',
    BackupSection.settings => '应用设置',
    BackupSection.presets => '对话预设',
    BackupSection.regexScripts => '正则脚本',
    BackupSection.memoryEntries => '记忆表格',
    BackupSection.schedulerJobs => '调度任务',
    BackupSection.proactiveRules => '主动消息规则',
    BackupSection.proactiveEvents => '主动消息事件',
    BackupSection.friendCircleRules => '朋友圈规则',
    BackupSection.walletTransactions => '余额流水',
    BackupSection.cartItems => '购物车',
    BackupSection.compatFiles => 'SillyTavern compat files',
    BackupSection.attachments => 'Attachments',
    BackupSection.attachmentIndex => '附件索引',
  };

  String get folderName => switch (this) {
    BackupSection.apiConfigs => 'api',
    BackupSection.contacts => 'contacts',
    BackupSection.messages => 'messages',
    BackupSection.moments => 'moments',
    BackupSection.settings => 'settings',
    BackupSection.presets => 'presets',
    BackupSection.regexScripts => 'regex',
    BackupSection.memoryEntries => 'memory',
    BackupSection.schedulerJobs => 'scheduler',
    BackupSection.proactiveRules => 'proactive_rules',
    BackupSection.proactiveEvents => 'proactive_events',
    BackupSection.friendCircleRules => 'friend_circle_rules',
    BackupSection.walletTransactions => 'wallet',
    BackupSection.cartItems => 'cart',
    BackupSection.compatFiles => 'st_compat',
    BackupSection.attachments => 'attachments',
    BackupSection.attachmentIndex => 'attachment_index',
  };
}

class BackupRestoreReport {
  final bool success;
  final String? error;
  final Map<BackupSection, int> restoredRows;
  final Map<BackupSection, int> restoredFiles;
  final List<String> details;

  const BackupRestoreReport({
    required this.success,
    this.error,
    this.restoredRows = const {},
    this.restoredFiles = const {},
    this.details = const [],
  });

  int rowsFor(BackupSection section) => restoredRows[section] ?? 0;
  int filesFor(BackupSection section) => restoredFiles[section] ?? 0;
}

class BackupService {
  /// 不进入备份/不写回的敏感 SharedPreferences key（凭据与密钥）。
  static const Set<String> _sensitivePrefsKeys = {
    'auto_backup_webdav_password',
    'auto_backup_webdav_username',
    'auto_backup_s3_secret_key',
    'auto_backup_s3_access_key',
    'auto_backup_password',
    'auto_backup_internal_key',
    'voice_tts_api_key',
    'voice_stt_api_key',
    'tts_config',
    'stt_config',
    'lansync_device_key',
  };

  final DatabaseService _dbService;
  final Future<void> Function()? _rebuildIndexes;
  final Future<AppPaths> Function() _createAppPaths;

  BackupService({
    DatabaseService? dbService,
    Future<void> Function()? rebuildIndexes,
    Future<AppPaths> Function()? createAppPaths,
  }) : _dbService = dbService ?? DatabaseService(),
       _rebuildIndexes = rebuildIndexes,
       _createAppPaths = createAppPaths ?? AppPaths.create;

  Future<String> exportToZip({
    required Set<BackupSection> sections,
    required String targetDir,
    String? password,
    bool forceEncrypt = false,
  }) async {
    if (forceEncrypt && (password == null || password.isEmpty)) {
      throw ArgumentError('云端备份必须加密，不能以明文上传');
    }
    final db = await _dbService.database;
    final archive = Archive();
    final manifestFiles = <Map<String, Object?>>[];
    final paths = await _createAppPaths();

    for (final section in sections) {
      final folder = section.folderName;
      switch (section) {
        case BackupSection.apiConfigs:
          // 安全：备份默认排除 api_key，恢复时保留本地现有 key。
          final apiRows = await db.query('api_configs');
          final sanitizedApiRows = apiRows
              .map(
                (row) =>
                    {...row}..removeWhere((key, _) => key == 'api_key'),
              )
              .toList();
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/api_configs.json',
            'section',
            sanitizedApiRows,
          );
        case BackupSection.contacts:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/contacts.json',
            'section',
            await db.query('contacts'),
          );
        case BackupSection.messages:
          final contacts = await db.query('contacts');
          for (final c in contacts) {
            final rows = await db.query(
              'messages',
              where: 'contact_id = ?',
              whereArgs: [c['id']],
            );
            if (rows.isEmpty) continue;
            final safeId = (c['id'] as String).replaceAll(
              RegExp(r'[^\w\-]'),
              '_',
            );
            _addBytesFile(
              archive,
              manifestFiles,
              '$folder/$safeId.json',
              utf8.encode(jsonEncode(rows)),
              'section',
            );
          }
        case BackupSection.moments:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/moments.json',
            'section',
            await db.query('moments'),
          );
        case BackupSection.settings:
          final prefs = await SharedPreferences.getInstance();
          final settings = <String, dynamic>{};
          for (final key in prefs.getKeys()) {
            // 安全：凭据类 key 一律不进入备份（WebDAV/S3 密码、TTS/STT
            // API key、LanSync 设备密钥、自动备份内部密钥等）。
            if (_sensitivePrefsKeys.contains(key)) continue;
            settings[key] = prefs.get(key);
          }
          _addBytesFile(
            archive,
            manifestFiles,
            '$folder/settings.json',
            utf8.encode(jsonEncode(settings)),
            'section',
          );
        case BackupSection.presets:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/presets.json',
            'section',
            await db.query('chat_presets'),
          );
        case BackupSection.regexScripts:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/regex_scripts.json',
            'section',
            await db.query('regex_scripts'),
          );
        case BackupSection.memoryEntries:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/memory_entries.json',
            'section',
            await db.query('memory_entries'),
          );
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/memory_states.json',
            'section',
            await db.query('memory_states'),
          );
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/memory_cards.json',
            'section',
            await db.query('memory_cards'),
          );
        case BackupSection.schedulerJobs:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/scheduler_jobs.json',
            'section',
            await db.query('scheduler_jobs'),
          );
        case BackupSection.proactiveRules:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/proactive_rules.json',
            'section',
            await db.query('proactive_rules'),
          );
        case BackupSection.proactiveEvents:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/proactive_events.json',
            'section',
            await db.query('proactive_events'),
          );
        case BackupSection.friendCircleRules:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/friend_circle_rules.json',
            'section',
            await db.query('friend_circle_rules'),
          );
        case BackupSection.walletTransactions:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/wallet_transactions.json',
            'section',
            await db.query('wallet_transactions'),
          );
        case BackupSection.cartItems:
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/cart_items.json',
            'section',
            await db.query('cart_items'),
          );
        case BackupSection.compatFiles:
          await _addDirectoryToArchive(
            archive,
            manifestFiles,
            paths.stCompat,
            'st_compat',
            'st_compat',
          );
        case BackupSection.attachments:
          await _addDirectoryToArchive(
            archive,
            manifestFiles,
            paths.attachments,
            'soultalk/attachments',
            'attachments',
          );
        case BackupSection.attachmentIndex:
          // 附件索引随备份保存（恢复后仍以文件系统重建兜底）。
          await _addJsonRowsFile(
            archive,
            manifestFiles,
            '$folder/attachment_index.json',
            'section',
            await db.query('attachment_index'),
          );
      }
    }

    final manifest = {
      'version': '1.1',
      'app': 'soultalk',
      'exported_at': DateTime.now().toIso8601String(),
      'sections': sections.map((s) => s.folderName).toList(),
      'files': manifestFiles,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipBytes = ZipEncoder().encode(archive);

    if (password != null && password.isNotEmpty) {
      final encrypted = BackupEncryption.encrypt(
        Uint8List.fromList(zipBytes),
        password,
      );
      final zipPath = p.join(targetDir, 'soultalk_backup_$timestamp.enc.zip');
      await File(zipPath).writeAsBytes(encrypted);
      return zipPath;
    }

    final zipPath = p.join(targetDir, 'soultalk_backup_$timestamp.zip');
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }

  Future<bool> importFromZip({
    required String zipPath,
    required Set<BackupSection> sections,
    String? password,
  }) async {
    return (await importFromZipWithReport(
      zipPath: zipPath,
      sections: sections,
      password: password,
    )).success;
  }

  Future<BackupRestoreReport> importFromZipWithReport({
    required String zipPath,
    required Set<BackupSection> sections,
    String? password,
  }) async {
    final restoredRows = <BackupSection, int>{};
    final restoredFiles = <BackupSection, int>{};
    final details = <String>[];
    void addRows(BackupSection section, int count) {
      restoredRows[section] = (restoredRows[section] ?? 0) + count;
    }

    void addFiles(BackupSection section, int count) {
      restoredFiles[section] = (restoredFiles[section] ?? 0) + count;
    }

    try {
      var bytes = await File(zipPath).readAsBytes();
      final isEnc = zipPath.endsWith('.enc.zip');

      if (isEnc) {
        // 自动备份使用本机内部密钥加密；用户未输入密码时回退到该密钥。
        var effectivePassword = password;
        if (effectivePassword == null || effectivePassword.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          effectivePassword = prefs.getString('auto_backup_internal_key');
        }
        if (effectivePassword == null || effectivePassword.isEmpty) {
          return const BackupRestoreReport(success: false, error: '缺少备份密码');
        }
        try {
          bytes = BackupEncryption.decrypt(
            Uint8List.fromList(bytes),
            effectivePassword,
          );
        } catch (_) {
          return const BackupRestoreReport(
            success: false,
            error: '备份密码错误或文件已损坏',
          );
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      // 解压大小上限：防止恶意 zip bomb 耗尽磁盘（解压后、写盘前检查）
      final totalSize = archive.files.fold<int>(
        0,
        (sum, f) => sum + f.size,
      );
      if (totalSize > _maxRestoreBytes) {
        return const BackupRestoreReport(
          success: false,
          error: '备份文件过大，拒绝恢复',
        );
      }
      final manifest = _readManifest(archive);
      if (manifest == null || manifest['app'] != 'soultalk') {
        return const BackupRestoreReport(
          success: false,
          error: '不是有效的 SoulTalk 备份',
        );
      }
      _validateManifestFiles(archive, manifest);
      details.add('Manifest ${manifest['version'] ?? 'unknown'} 校验通过');
      await _createRestorePoint();
      details.add('已创建本地恢复点');

      final db = await _dbService.database;

      // ── DB 表恢复 ──────────────────────────────────────────────
      // 按外键依赖顺序（contacts 必须先于 messages/moments/memory），
      // 且包在单个事务中：中途失败自动回滚，不留半恢复状态。
      const dbRestoreOrder = [
        BackupSection.apiConfigs,
        BackupSection.contacts,
        BackupSection.presets,
        BackupSection.regexScripts,
        BackupSection.memoryEntries,
        BackupSection.moments,
        BackupSection.messages,
        BackupSection.schedulerJobs,
        BackupSection.proactiveRules,
        BackupSection.proactiveEvents,
        BackupSection.friendCircleRules,
        BackupSection.walletTransactions,
        BackupSection.cartItems,
        BackupSection.attachmentIndex,
      ];
      final dbSections = sections.where(dbRestoreOrder.contains).toList();
      dbSections.sort((a, b) {
        final ia = dbRestoreOrder.indexOf(a);
        final ib = dbRestoreOrder.indexOf(b);
        return ia.compareTo(ib);
      });

      if (dbSections.isNotEmpty) {
        await db.transaction((txn) async {
          for (final section in dbSections) {
            final folder = section.folderName;
            switch (section) {
              case BackupSection.apiConfigs:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/api_configs.json',
                    'api_configs',
                    // 备份不含 api_key：已存在时保留本地 key，
                    // 新配置则补空字符串（用户重新填写）。
                    preserveColumns: const {'api_key'},
                    insertDefaults: const {'api_key': ''},
                  ),
                );
              case BackupSection.contacts:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/contacts.json',
                    'contacts',
                  ),
                );
              case BackupSection.messages:
                for (final file in archive.files) {
                  if (!file.isFile ||
                      !file.name.startsWith('$folder/') ||
                      !file.name.endsWith('.json')) {
                    continue;
                  }
                  addRows(
                    section,
                    await _restoreRows(txn, archive, file.name, 'messages'),
                  );
                }
              case BackupSection.moments:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/moments.json',
                    'moments',
                  ),
                );
              case BackupSection.presets:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/presets.json',
                    'chat_presets',
                  ),
                );
              case BackupSection.regexScripts:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/regex_scripts.json',
                    'regex_scripts',
                  ),
                );
              case BackupSection.memoryEntries:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/memory_entries.json',
                    'memory_entries',
                  ),
                );
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/memory_states.json',
                    'memory_states',
                  ),
                );
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/memory_cards.json',
                    'memory_cards',
                  ),
                );
              case BackupSection.schedulerJobs:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/scheduler_jobs.json',
                    'scheduler_jobs',
                  ),
                );
              case BackupSection.proactiveRules:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/proactive_rules.json',
                    'proactive_rules',
                  ),
                );
              case BackupSection.proactiveEvents:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/proactive_events.json',
                    'proactive_events',
                  ),
                );
              case BackupSection.friendCircleRules:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/friend_circle_rules.json',
                    'friend_circle_rules',
                  ),
                );
              case BackupSection.walletTransactions:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/wallet_transactions.json',
                    'wallet_transactions',
                  ),
                );
              case BackupSection.cartItems:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/cart_items.json',
                    'cart_items',
                  ),
                );
              case BackupSection.settings:
              case BackupSection.compatFiles:
              case BackupSection.attachments:
                break; // 非 DB 表，事务外处理
              case BackupSection.attachmentIndex:
                addRows(
                  section,
                  await _restoreRows(
                    txn,
                    archive,
                    '$folder/attachment_index.json',
                    'attachment_index',
                  ),
                );
            }
          }
        });
      }

      // ── Settings（SharedPreferences，非 DB）──
      // 事务化：先完成解析/校验，再写入；写入失败时按快照回滚已写 key，
      // 避免留下半恢复状态。
      if (sections.contains(BackupSection.settings)) {
        final file = archive.findFile('settings/settings.json');
        if (file != null) {
          final settings =
              jsonDecode(_contentString(file)) as Map<String, dynamic>;
          // 校验阶段：过滤敏感 key 与不支持的类型，得到类型化条目列表。
          final typed = <(String, Object)>[];
          for (final entry in settings.entries) {
            // 防御：即使旧备份含凭据 key 也不写回。
            if (_sensitivePrefsKeys.contains(entry.key)) continue;
            final v = entry.value;
            if (v is int || v is double || v is bool || v is String) {
              typed.add((entry.key, v));
            }
          }
          final prefs = await SharedPreferences.getInstance();
          // 快照旧值（回滚用）；读不到视为原本不存在。
          final oldValues = <String, Object?>{};
          for (final (key, _) in typed) {
            if (prefs.containsKey(key)) {
              oldValues[key] = _readPrefValue(prefs, key);
            }
          }
          var count = 0;
          try {
            for (final (key, v) in typed) {
              await _writePrefValue(prefs, key, v);
              count++;
            }
          } catch (_) {
            // 回滚已写入的 key 到旧值；原本不存在的 key 移除。
            for (final (key, _) in typed) {
              final old = oldValues[key];
              try {
                if (old == null) {
                  if (prefs.containsKey(key)) await prefs.remove(key);
                } else {
                  await _writePrefValue(prefs, key, old);
                }
              } catch (_) {}
            }
            rethrow;
          }
          addRows(BackupSection.settings, count);
        }
      }

      // ── 文件恢复（st_compat / attachments）──
      if (sections.contains(BackupSection.compatFiles)) {
        final paths = await _createAppPaths();
        addFiles(
          BackupSection.compatFiles,
          await _restoreArchiveDirectory(archive, 'st_compat', paths.stCompat),
        );
      }
      if (sections.contains(BackupSection.attachments)) {
        final paths = await _createAppPaths();
        addFiles(
          BackupSection.attachments,
          await _restoreArchiveDirectory(
            archive,
            'soultalk/attachments',
            paths.attachments,
          ),
        );
      }

      if (sections.contains(BackupSection.compatFiles) ||
          sections.contains(BackupSection.attachments) ||
          sections.contains(BackupSection.attachmentIndex)) {
        await _rebuildRestoredIndexes();
        details.add('已重建文件索引');
      }
      return BackupRestoreReport(
        success: true,
        restoredRows: restoredRows,
        restoredFiles: restoredFiles,
        details: details,
      );
    } catch (e) {
      return BackupRestoreReport(
        success: false,
        error: e.toString(),
        details: details,
      );
    }
  }

  Future<void> _addJsonRowsFile(
    Archive archive,
    List<Map<String, Object?>> manifestFiles,
    String archivePath,
    String domain,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return;
    _addBytesFile(
      archive,
      manifestFiles,
      archivePath,
      utf8.encode(jsonEncode(rows)),
      domain,
    );
  }

  void _addBytesFile(
    Archive archive,
    List<Map<String, Object?>> manifestFiles,
    String archivePath,
    List<int> bytes,
    String domain, {
    int? mtime,
  }) {
    archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
    manifestFiles.add({
      'archive_path': archivePath,
      'domain': domain,
      'sha256': sha256.convert(bytes).toString(),
      'size': bytes.length,
      'mtime': mtime ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    List<Map<String, Object?>> manifestFiles,
    Directory directory,
    String archiveRoot,
    String domain,
  ) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final relative = p
          .relative(entity.path, from: directory.path)
          .split(p.separator)
          .join('/');
      final stat = await entity.stat();
      _addBytesFile(
        archive,
        manifestFiles,
        '$archiveRoot/$relative',
        bytes,
        domain,
        mtime: stat.modified.millisecondsSinceEpoch,
      );
    }
  }

  /// 恢复归档目录（st_compat / attachments）。
  ///
  /// 事务化语义，避免半恢复状态：
  /// 1. 先把全部文件解压到同卷 staging 目录（失败 → 删除 staging，目标不变）；
  /// 2. 落位：逐个把目标旧文件移入 backup 目录、staging 文件 rename 到目标；
  /// 3. 全部成功 → 删除 backup/staging；任一步失败 → 把 backup 中旧文件
  ///    rename 回目标，删除残留 staging/backup，抛异常（目标保持原样）。
  Future<int> _restoreArchiveDirectory(
    Archive archive,
    String archiveRoot,
    Directory targetRoot,
  ) async {
    final staging = Directory('${targetRoot.path}.staging');
    final backup = Directory('${targetRoot.path}.backup');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    if (await backup.exists()) {
      await backup.delete(recursive: true);
    }

    // 阶段 1：解压到 staging（不触碰目标目录）
    final entries = <(String relative, File stagingFile)>[];
    try {
      for (final file in archive.files) {
        if (!file.isFile || !file.name.startsWith('$archiveRoot/')) continue;
        final relative = file.name.substring(archiveRoot.length + 1);
        _validateRelativeArchivePath(relative);
        final stagingFile = File(
          p.joinAll([staging.path, ...relative.split('/')]),
        );
        await stagingFile.parent.create(recursive: true);
        await stagingFile.writeAsBytes(_contentBytes(file), flush: true);
        entries.add((relative, stagingFile));
      }
    } catch (_) {
      await _deleteIfExists(staging);
      await _deleteIfExists(backup);
      rethrow;
    }

    // 阶段 2：落位（旧文件先移入 backup，staging rename 到目标）
    try {
      for (final (relative, stagingFile) in entries) {
        final target = _safeTargetFile(targetRoot, relative);
        await target.parent.create(recursive: true);
        if (await target.exists()) {
          final oldBackup = File(p.joinAll([backup.path, ...relative.split('/')]));
          await oldBackup.parent.create(recursive: true);
          await target.rename(oldBackup.path);
        }
        await stagingFile.rename(target.path);
      }
    } catch (_) {
      // 回滚：把已移走的旧文件 rename 回目标
      if (await backup.exists()) {
        await for (final entity in backup.list(recursive: true)) {
          if (entity is! File) continue;
          final relative = p
              .relative(entity.path, from: backup.path)
              .split(p.separator)
              .join('/');
          try {
            final target = _safeTargetFile(targetRoot, relative);
            await target.parent.create(recursive: true);
            await entity.rename(target.path);
          } catch (_) {
            // 尽力回滚，失败由上层 report.error 暴露
          }
        }
      }
      await _deleteIfExists(staging);
      await _deleteIfExists(backup);
      rethrow;
    }

    await _deleteIfExists(backup);
    await _deleteIfExists(staging);
    return entries.length;
  }

  Future<void> _deleteIfExists(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// 备份解压总大小上限（4 GiB）。
  static const int _maxRestoreBytes = 4 * 1024 * 1024 * 1024;

  /// 合法 SQL 列名：仅小写字母/数字/下划线。
  static final RegExp _safeColumnName = RegExp(r'^[a-z_][a-z0-9_]*$');

  static bool _isSafeColumnName(String name) =>
      _safeColumnName.hasMatch(name) && !name.startsWith('sqlite_');

  /// 恢复行数据，使用真正的 UPSERT 语义：
  /// 先尝试 INSERT；主键冲突时改为 UPDATE（不会触发 SQLite REPLACE 的
  /// “先 DELETE 再 INSERT”，避免级联删除联系人下的消息/朋友圈/记忆）。
  ///
  /// [preserveColumns]：冲突更新时保留数据库现有值（如 api_key）；
  /// 插入新行且缺少这些列时使用 [insertDefaults] 补齐（NOT NULL 约束）。
  Future<int> _restoreRows(
    DatabaseExecutor db,
    Archive archive,
    String archivePath,
    String table, {
    Set<String>? preserveColumns,
    Map<String, Object?> insertDefaults = const {},
  }) async {
    final file = archive.findFile(archivePath);
    if (file == null) return 0;
    final rows = jsonDecode(_contentString(file)) as List;
    for (final row in rows) {
      final data = Map<String, Object?>.from(row as Map);
      // 安全：sqflite insert/update 直接拼接列名，恶意备份可构造列名
      // 实现 SQL 注入。仅保留合法列名（小写字母/数字/下划线，
      // 不以 sqlite_ 开头），其余丢弃。
      data.removeWhere((key, _) => !_isSafeColumnName(key));
      if (preserveColumns != null && preserveColumns.isNotEmpty) {
        final id = data['id'];
        final existing = id == null
            ? const <Map<String, Object?>>[]
            : await db.query(
                table,
                columns: preserveColumns.toList(),
                where: 'id = ?',
                whereArgs: [id],
                limit: 1,
              );
        for (final column in preserveColumns) {
          if (existing.isNotEmpty) {
            data[column] = existing.first[column];
          } else if (!data.containsKey(column) &&
              insertDefaults.containsKey(column)) {
            data[column] = insertDefaults[column];
          }
        }
      }
      try {
        await db.insert(table, data);
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError()) {
          final id = data['id'];
          if (id == null) rethrow;
          await db.update(table, data, where: 'id = ?', whereArgs: [id]);
        } else {
          rethrow;
        }
      }
    }
    return rows.length;
  }

  Map<String, dynamic>? _readManifest(Archive archive) {
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) return null;
    return jsonDecode(_contentString(manifestFile)) as Map<String, dynamic>;
  }

  void _validateManifestFiles(Archive archive, Map<String, dynamic> manifest) {
    final files = manifest['files'];
    if (files is! List) throw const FormatException('Invalid manifest files');
    for (final entry in files) {
      if (entry is! Map) throw const FormatException('Invalid manifest entry');
      final archivePath = entry['archive_path'];
      final expectedSha = entry['sha256'];
      final expectedSize = entry['size'];
      if (archivePath is! String ||
          expectedSha is! String ||
          expectedSize is! int) {
        throw const FormatException('Invalid manifest entry fields');
      }
      _validateArchivePath(archivePath);
      final file = archive.findFile(archivePath);
      if (file == null || !file.isFile) {
        throw FormatException('Missing archive file: $archivePath');
      }
      final bytes = _contentBytes(file);
      if (bytes.length != expectedSize) {
        throw FormatException('Size mismatch: $archivePath');
      }
      if (sha256.convert(bytes).toString() != expectedSha) {
        throw FormatException('Hash mismatch: $archivePath');
      }
    }
  }

  Future<void> _createRestorePoint() async {
    try {
      final paths = await _createAppPaths();
      final dir = Directory(p.join(paths.soultalk.path, 'restore_points'));
      await dir.create(recursive: true);
      await exportToZip(
        sections: BackupSection.values.toSet(),
        targetDir: dir.path,
      );
      await _pruneRestorePoints(dir);
    } catch (error, stackTrace) {
      // 恢复点只是额外保险：创建失败不应阻断恢复流程本身
      developer.log(
        'Failed to create restore point',
        name: 'BackupService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 恢复点只保留最近 [keep] 个，避免磁盘无限膨胀。
  Future<void> _pruneRestorePoints(Directory dir, {int keep = 3}) async {
    try {
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.zip')) {
          files.add(entity);
        }
      }
      files.sort((a, b) => b.path.compareTo(a.path));
      for (final file in files.skip(keep)) {
        await file.delete();
      }
    } catch (error) {
      // 清理失败不影响恢复流程
      developer.log(
        'Failed to prune restore points',
        name: 'BackupService',
        error: error,
      );
    }
  }

  Future<void> _rebuildRestoredIndexes() async {
    if (_rebuildIndexes != null) {
      await _rebuildIndexes();
    } else {
      final bootstrap = await CompatStorageBootstrapService.create();
      await bootstrap.initializeAndRebuildIndex();
    }
    // 附件索引以文件系统为权威源重建（message_id 关联由消息 metadata 承载）。
    final paths = await _createAppPaths();
    await AttachmentIndexDao(_dbService).rebuildFromDirectory(paths.attachments);
  }

  void _validateArchivePath(String archivePath) {
    if (archivePath.isEmpty ||
        archivePath.contains('\\') ||
        p.isAbsolute(archivePath)) {
      throw FormatException('Invalid archive path: $archivePath');
    }
    _validateRelativeArchivePath(archivePath);
  }

  void _validateRelativeArchivePath(String relative) {
    final parts = relative.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Invalid archive path: $relative');
    }
  }

  File _safeTargetFile(Directory targetRoot, String relative) {
    final target = File(p.joinAll([targetRoot.path, ...relative.split('/')]));
    final rootPath = p.normalize(targetRoot.absolute.path);
    final targetPath = p.normalize(target.absolute.path);
    if (targetPath != rootPath && !p.isWithin(rootPath, targetPath)) {
      throw FormatException('Invalid restore target: $relative');
    }
    return target;
  }

  List<int> _contentBytes(ArchiveFile file) => file.content as List<int>;

  String _contentString(ArchiveFile file) => utf8.decode(_contentBytes(file));

  /// 读取 SharedPreferences 中某个 key 的旧值（按类型尝试）。
  Object? _readPrefValue(SharedPreferences prefs, String key) {
    final s = prefs.getString(key);
    if (s != null) return s;
    final i = prefs.getInt(key);
    if (i != null) return i;
    final d = prefs.getDouble(key);
    if (d != null) return d;
    final b = prefs.getBool(key);
    if (b != null) return b;
    return prefs.getStringList(key);
  }

  /// 按类型写回 SharedPreferences。
  Future<void> _writePrefValue(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  Future<List<BackupSection>> listSections(
    String zipPath, {
    String? password,
  }) async {
    try {
      var bytes = await File(zipPath).readAsBytes();

      if (zipPath.endsWith('.enc.zip')) {
        if (password == null || password.isEmpty) return [];
        try {
          bytes = BackupEncryption.decrypt(Uint8List.fromList(bytes), password);
        } catch (_) {
          return [];
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = _readManifest(archive);
      if (manifest == null) return [];
      final sectionNames =
          (manifest['sections'] as List?)?.cast<String>() ?? [];

      return sectionNames
          .map(
            (name) =>
                BackupSection.values.firstWhere((s) => s.folderName == name),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
