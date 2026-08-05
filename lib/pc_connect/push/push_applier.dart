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
    try {
      final result = validator.validate(proposal);
      return {
        'accepted': result.allowed,
        if (!result.allowed) 'reason': result.reason,
      };
    } catch (error) {
      return {'accepted': false, 'reason': 'invalid_proposal: $error'};
    }
  }

  /// 校验通过后将推送的变更真正应用到本地数据库。
  ///
  /// 返回结构：
  /// - accepted=false：校验未通过（含 reason）
  /// - accepted=true, applied=true：已写入
  /// - accepted=true, applied=false：重复/外键失败等（含 reason）
  Future<Map<String, dynamic>> apply(Map<String, dynamic> proposal) async {
    PushValidationResult result;
    try {
      // 畸形类型（如 operation 为数字）在此被捕获，避免 TypeError 上抛
      result = validator.validate(proposal);
    } catch (error) {
      return {'accepted': false, 'reason': 'invalid_proposal: $error'};
    }
    if (!result.allowed) {
      return {'accepted': false, 'reason': result.reason};
    }

    final table = proposal['table'] as String;
    final row = proposal['row'] as Map<String, dynamic>;
    final rowId = row['id'];

    // id 必须为非空字符串：数字/null id 会绕过 TEXT 主键查重
    if (rowId is! String || rowId.isEmpty) {
      return {'accepted': true, 'applied': false, 'reason': 'invalid_id'};
    }

    try {
      final db = await (dbService ?? DatabaseService()).database;
      // rowId 已保证为非空 String（见上方 invalid_id 检查）
      final existing = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [rowId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return {'accepted': true, 'applied': false, 'reason': 'duplicate'};
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
