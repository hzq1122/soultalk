import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_paths.dart';
import '../database/database_service.dart';
import '../database/scheduler_job_dao.dart';
import '../scheduler/scheduler_task_handler.dart';
import 'backup_service.dart';
import 'cloud_storage.dart';

class AutoBackupRunResult {
  final bool success;
  final String summary;

  const AutoBackupRunResult({required this.success, required this.summary});
}

class AutoBackupService {
  static const jobType = 'auto_backup';
  static const jobTargetId = 'global';
  static const jobId = 'auto_backup_global';

  /// 备份自身写入的状态 key：变化不代表业务数据变化，不参与指纹。
  static const Set<String> _stateKeys = {
    'auto_backup_last_hash',
    'auto_backup_last_time',
    'auto_backup_last_error',
    'auto_backup_internal_key',
  };

  /// 凭据 key：备份内容不含它们（见 BackupService 敏感 key 过滤），
  /// 变化不触发自动备份。
  static const Set<String> _credentialKeys = {
    'auto_backup_webdav_password',
    'auto_backup_webdav_username',
    'auto_backup_s3_secret_key',
    'auto_backup_s3_access_key',
    'auto_backup_password',
    'voice_tts_api_key',
    'voice_stt_api_key',
    'tts_config',
    'stt_config',
    'lansync_device_key',
  };

  static final AutoBackupService _instance = AutoBackupService._internal();
  factory AutoBackupService() => _instance;

  AutoBackupService.forTesting({
    DatabaseService? dbService,
    Future<AppPaths> Function()? createAppPaths,
  }) : _dbService = dbService ?? DatabaseService(),
       _createAppPaths = createAppPaths ?? AppPaths.create;

  AutoBackupService._internal({DatabaseService? dbService})
    : _dbService = dbService ?? DatabaseService(),
      _createAppPaths = AppPaths.create;

  final DatabaseService _dbService;
  final Future<AppPaths> Function() _createAppPaths;
  final BackupService _backupService = BackupService();
  final SchedulerJobDao _schedulerJobDao = SchedulerJobDao(DatabaseService());

  Future<void> init() async {
    await syncSchedule();
  }

  void dispose() {}

  Future<void> syncSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('auto_backup_enabled') ?? false;
    final intervalMinutes = prefs.getInt('auto_backup_interval') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _schedulerJobDao.getByTypeTarget(
      jobType,
      jobTargetId,
    );

    if (!enabled || intervalMinutes <= 0) {
      if (existing != null) await _schedulerJobDao.disable(existing.id);
      return;
    }

    await _schedulerJobDao.upsert(
      SchedulerJobRecord(
        id: existing?.id ?? jobId,
        type: jobType,
        targetId: jobTargetId,
        runAfter: existing?.status == 'pending'
            ? existing!.runAfter
            : now + Duration(minutes: intervalMinutes).inMilliseconds,
        retryCount: existing?.retryCount ?? 0,
        status: 'pending',
        payload: '{}',
        lastError: null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<AutoBackupRunResult> runOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_backup_enabled') ?? false;
      if (!enabled) {
        return const AutoBackupRunResult(success: true, summary: 'disabled');
      }

      final lastHash = prefs.getString('auto_backup_last_hash');
      final db = await _dbService.database;
      final currentHash = await _computeFingerprint(db, prefs);
      if (currentHash == lastHash) {
        return const AutoBackupRunResult(success: true, summary: 'no changes');
      }

      final storage = await _createStorage(prefs);
      if (storage == null) {
        return const AutoBackupRunResult(
          success: true,
          summary: 'no cloud storage configured',
        );
      }

      final tempDir = (await getTemporaryDirectory()).path;
      // 云端备份强制加密：优先使用用户配置的备份密码，否则使用本机
      // 内部密钥（首次自动生成并持久化），避免备份文件在云端明文存放。
      final password =
          prefs.getString('auto_backup_password') ?? await _internalKey(prefs);
      final path = await _backupService.exportToZip(
        sections: BackupSection.values.toSet(),
        targetDir: tempDir,
        password: password,
      );

      final fileName = p.basename(path);
      final success = await storage.upload(path, fileName);
      if (!success) {
        await prefs.setString('auto_backup_last_error', 'Upload failed');
        return const AutoBackupRunResult(
          success: false,
          summary: 'upload failed',
        );
      }

      await prefs.setString('auto_backup_last_hash', currentHash);
      await prefs.setString(
        'auto_backup_last_time',
        DateTime.now().toIso8601String(),
      );
      await prefs.remove('auto_backup_last_error');
      return const AutoBackupRunResult(success: true, summary: 'uploaded');
    } catch (e, stackTrace) {
      developer.log(
        'Auto backup failed',
        name: 'AutoBackupService',
        error: e,
        stackTrace: stackTrace,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_backup_last_error', e.toString());
      return AutoBackupRunResult(success: false, summary: e.toString());
    }
  }

  /// 读取或生成自动备份内部密钥（32 字符随机串，持久化于本机 prefs）。
  /// 该密钥绝不会写入备份内容（见 BackupService 的敏感 key 过滤）。
  Future<String> _internalKey(SharedPreferences prefs) async {
    const key = 'auto_backup_internal_key';
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final generated = List.generate(
      32,
      (_) =>
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[rng
              .nextInt(62)],
    ).join();
    await prefs.setString(key, generated);
    return generated;
  }

  /// 计算变更检测指纹：覆盖全部数据表（count + 时间戳列最大值）、
  /// 全部非敏感 SharedPreferences 设置、以及 st_compat/attachments
  /// 文件目录（文件数 + 总大小 + 最新 mtime）。
  ///
  /// 排除：scheduler_run_log（诊断日志）、auto_backup 自身状态 key
  /// （避免自指导致每次备份）、凭据 key（备份内容不含它们）。
  /// （公开供测试与诊断使用。）
  Future<String> computeFingerprint(Database db, SharedPreferences prefs) =>
      _computeFingerprint(db, prefs);

  Future<String> _computeFingerprint(
    Database db,
    SharedPreferences prefs,
  ) async {
    final parts = <String>[];

    // 1. 数据表：count + 时间戳列（updated_at 优先，其次 created_at）
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    for (final row in tables) {
      final table = row['name'] as String;
      if (table == 'scheduler_run_log') continue;
      // 表名来自 sqlite_master，非用户输入；列名来自 PRAGMA 返回。
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final names = cols.map((c) => c['name'] as String).toSet();
      String? tsColumn;
      if (names.contains('updated_at')) {
        tsColumn = 'updated_at';
      } else if (names.contains('created_at')) {
        tsColumn = 'created_at';
      }
      if (tsColumn != null) {
        final r = (await db.rawQuery(
          'SELECT COUNT(*) AS c, MAX($tsColumn) AS m FROM $table',
        )).first;
        parts.add('$table:${r['c']}:${r['m']}');
      } else {
        final r = (await db.rawQuery('SELECT COUNT(*) AS c FROM $table')).first;
        parts.add('$table:${r['c']}');
      }
    }

    // 2. 设置（排除状态与凭据 key，避免自指/无意义触发）
    final prefParts = <String>[];
    final keys = prefs.getKeys().toList()..sort();
    for (final key in keys) {
      if (_stateKeys.contains(key) || _credentialKeys.contains(key)) continue;
      prefParts.add('$key=${_readPrefValue(prefs, key)}');
    }
    parts.add(
      'prefs:${sha256.convert(utf8.encode(prefParts.join('|'))).toString()}',
    );

    // 3. 文件目录（st_compat / attachments）
    final paths = await _createAppPaths();
    parts.add(await _dirFingerprint('st_compat', paths.stCompat));
    parts.add(await _dirFingerprint('attachments', paths.attachments));

    return sha256.convert(utf8.encode(parts.join('|'))).toString();
  }

  /// 目录指纹：文件数 + 总大小 + 最新 mtime（不读内容，开销小）。
  Future<String> _dirFingerprint(String name, Directory dir) async {
    if (!await dir.exists()) return '$name:absent';
    var count = 0;
    var totalSize = 0;
    var maxMtime = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      count++;
      final stat = await entity.stat();
      totalSize += stat.size;
      final mtime = stat.modified.millisecondsSinceEpoch;
      if (mtime > maxMtime) maxMtime = mtime;
    }
    return '$name:$count:$totalSize:$maxMtime';
  }

  /// 按类型读取 prefs 值（SharedPreferences 无泛型 getter）。
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

  Future<CloudStorage?> _createStorage(SharedPreferences prefs) async {
    final cloudType = prefs.getString('auto_backup_cloud_type');
    if (cloudType == 'webdav') {
      final url = prefs.getString('auto_backup_webdav_url') ?? '';
      final username = prefs.getString('auto_backup_webdav_username') ?? '';
      final password = prefs.getString('auto_backup_webdav_password') ?? '';
      if (url.isNotEmpty && username.isNotEmpty) {
        return WebDavStorage(
          WebDavConfig(url: url, username: username, password: password),
        );
      }
    } else if (cloudType == 's3') {
      final endpoint = prefs.getString('auto_backup_s3_endpoint') ?? '';
      final bucket = prefs.getString('auto_backup_s3_bucket') ?? '';
      if (endpoint.isNotEmpty && bucket.isNotEmpty) {
        return S3Storage(
          S3Config(
            endpoint: endpoint,
            region: prefs.getString('auto_backup_s3_region') ?? '',
            accessKey: prefs.getString('auto_backup_s3_access_key') ?? '',
            secretKey: prefs.getString('auto_backup_s3_secret_key') ?? '',
            bucket: bucket,
          ),
        );
      }
    }
    return null;
  }
}

class AutoBackupTaskHandler implements SchedulerTaskHandler {
  final AutoBackupService service;

  AutoBackupTaskHandler({AutoBackupService? service})
    : service = service ?? AutoBackupService();

  @override
  String get type => AutoBackupService.jobType;

  @override
  Future<SchedulerTaskResult> run(SchedulerJobRecord job) async {
    final result = await service.runOnce();
    final prefs = await SharedPreferences.getInstance();
    final intervalMinutes = prefs.getInt('auto_backup_interval') ?? 0;
    final nextRunAfterMillis = intervalMinutes > 0
        ? DateTime.now()
              .add(Duration(minutes: intervalMinutes))
              .millisecondsSinceEpoch
        : null;
    if (result.success) {
      return SchedulerTaskResult.success(
        summary: result.summary,
        nextRunAfterMillis: nextRunAfterMillis,
      );
    }
    return SchedulerTaskResult.failure(error: result.summary);
  }
}
