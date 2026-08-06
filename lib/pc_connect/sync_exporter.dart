import 'package:sqflite/sqflite.dart';

import '../services/database/database_service.dart';

class SyncExporter {
  final DatabaseService dbService;

  SyncExporter({required this.dbService});

  /// 每张表的列名缓存（避免每页拉取都执行 PRAGMA）。
  final Map<String, Set<String>> _columnCache = {};

  Future<Map<String, dynamic>> exportRows({
    required String table,
    List<String>? ids,
    int limit = 500,

    /// 游标：只导出 id > [after] 的行（keyset 分页续拉）。
    String? after,

    /// 修改水位：只导出 COALESCE(updated_at, created_at) > [afterUpdatedAt]
    /// 的行（含原地修改的行）。与 [after] 组合使用时可精确续拉。
    String? afterUpdatedAt,
  }) async {
    if (!_allowedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Table is not syncable');
    }
    // 服务层兜底：限制单次导出数量，防止调用方绕过服务器钳制
    final safeLimit = limit.clamp(1, 500);
    final safeIds = ids?.take(500).toList();
    final db = await dbService.database;
    final rows = await _queryRows(
      db,
      table,
      safeIds,
      safeLimit,
      after,
      afterUpdatedAt,
    );
    return {
      'table': table,
      'rows': rows,
      'hasMore': safeIds == null && rows.length == safeLimit,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 是否支持 updated_at 增量水位（有 updated_at 列的表）。
  /// messages/moments 自 v14 起具备该列；contacts/memory_entries 等
  /// 自带该列；无该列的表保持 id 游标（仅新增可同步）。
  Future<bool> supportsUpdatedAtWatermark(String table) async {
    final db = await dbService.database;
    return (await _columnNames(db, table)).contains('updated_at');
  }

  Future<Set<String>> _columnNames(Database db, String table) async {
    final cached = _columnCache[table];
    if (cached != null) return cached;
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final names = cols.map((c) => c['name'] as String).toSet();
    _columnCache[table] = names;
    return names;
  }

  Future<List<Map<String, Object?>>> _queryRows(
    Database db,
    String table,
    List<String>? ids,
    int limit,
    String? after,
    String? afterUpdatedAt,
  ) async {
    if (ids == null || ids.isEmpty) {
      final hasWatermark =
          afterUpdatedAt != null &&
          (await _columnNames(db, table)).contains('updated_at');
      if (hasWatermark) {
        // 修改水位游标：COALESCE(updated_at, created_at) 升序 + id 升序，
        // 保证原地修改的行（updated_at 刷新）会被重新拉取；
        // 时间相等时用 id 精确续拉，避免重复/遗漏。
        return db.query(
          table,
          where:
              'COALESCE(updated_at, created_at) > ? '
              'OR (COALESCE(updated_at, created_at) = ? AND id > ?)',
          whereArgs: [afterUpdatedAt, afterUpdatedAt, after ?? ''],
          orderBy: 'COALESCE(updated_at, created_at) ASC, id ASC',
          limit: limit,
        );
      }
      return db.query(
        table,
        where: after != null ? 'id > ?' : null,
        whereArgs: after != null ? [after] : null,
        orderBy: 'id ASC',
        limit: limit,
      );
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.query(
      table,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  static const _allowedTables = {
    'contacts',
    'messages',
    'moments',
    'chat_presets',
    'regex_scripts',
    'memory_entries',
    'memory_states',
    'memory_cards',
    'pc_deletions',
  };
}
