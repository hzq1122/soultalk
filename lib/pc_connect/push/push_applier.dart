import 'package:sqflite/sqflite.dart';

import '../../services/database/database_service.dart';
import 'push_validator.dart';

class PushApplier {
  final PushValidator validator;
  final DatabaseService? dbService;

  const PushApplier({this.validator = const PushValidator(), this.dbService});

  /// 仅校验（保持向后兼容）。
  Future<Map<String, dynamic>> validateOnly(
    Map<String, dynamic> proposal,
  ) async {
    final result = validator.validate(proposal);
    return {
      'accepted': result.allowed,
      if (!result.allowed) 'reason': result.reason,
    };
  }

  /// 校验通过后将推送的变更真正应用到本地数据库。
  ///
  /// 返回结构：
  /// - accepted=false：校验未通过（含 reason）
  /// - accepted=true, applied=true：已写入
  /// - accepted=true, applied=false：重复/外键失败等（含 reason）
  Future<Map<String, dynamic>> apply(Map<String, dynamic> proposal) async {
    final result = validator.validate(proposal);
    if (!result.allowed) {
      return {'accepted': false, 'reason': result.reason};
    }

    final table = proposal['table'] as String;
    final row = proposal['row'] as Map<String, dynamic>;
    final rowId = row['id'];

    try {
      final db = await (dbService ?? DatabaseService()).database;
      if (rowId != null) {
        final existing = await db.query(
          table,
          where: 'id = ?',
          whereArgs: [rowId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return {'accepted': true, 'applied': false, 'reason': 'duplicate'};
        }
      }
      await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
      return {'accepted': true, 'applied': true};
    } catch (error) {
      // 外键失败（contact 不存在）或非法列名等
      return {
        'accepted': true,
        'applied': false,
        'reason': 'apply_failed: $error',
      };
    }
  }
}
