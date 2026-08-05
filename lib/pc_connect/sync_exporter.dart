import 'package:sqflite/sqflite.dart';

import '../services/database/database_service.dart';

class SyncExporter {
  final DatabaseService dbService;

  const SyncExporter({required this.dbService});

  Future<Map<String, dynamic>> exportRows({
    required String table,
    List<String>? ids,
    int limit = 500,
    /// 游标：只导出 id > [after] 的行（keyset 分页续拉）。
    String? after,
  }) async {
    if (!_allowedTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Table is not syncable');
    }
    // 服务层兜底：限制单次导出数量，防止调用方绕过服务器钳制
    final safeLimit = limit.clamp(1, 500);
    final safeIds = ids?.take(500).toList();
    final db = await dbService.database;
    final rows = await _queryRows(db, table, safeIds, safeLimit, after);
    return {
      'table': table,
      'rows': rows,
      'hasMore': safeIds == null && rows.length == safeLimit,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, Object?>>> _queryRows(
    Database db,
    String table,
    List<String>? ids,
    int limit,
    String? after,
  ) {
    if (ids == null || ids.isEmpty) {
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
