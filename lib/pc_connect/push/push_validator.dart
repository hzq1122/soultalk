class PushValidationResult {
  final bool allowed;
  final String? reason;

  const PushValidationResult.allowed() : allowed = true, reason = null;
  const PushValidationResult.rejected(this.reason) : allowed = false;
}

class PushValidator {
  const PushValidator();

  static const _allowedTables = {'messages'};
  static const _allowedOperations = {'insert'};
  static const _secretFields = {
    'api_key',
    'password',
    'secret',
    'access_key',
    'secret_key',
    'token',
  };
  /// messages 表已知列白名单：sqflite insert 不转义列名，
  /// 未知列名可被构造为 SQL 注入载荷，必须拒绝。
  static const _messagesColumns = {
    'id',
    'contact_id',
    'role',
    'content',
    'type',
    'is_streaming',
    'token_count',
    'metadata',
    'created_at',
  };

  PushValidationResult validate(Map<String, dynamic> proposal) {
    final table = proposal['table'] as String?;
    final operation = proposal['operation'] as String?;
    final row = proposal['row'];
    if (table == null || !_allowedTables.contains(table)) {
      return PushValidationResult.rejected('table_not_allowed');
    }
    if (operation == null || !_allowedOperations.contains(operation)) {
      return PushValidationResult.rejected('operation_not_allowed');
    }
    if (row is! Map<String, dynamic>) {
      return PushValidationResult.rejected('invalid_row');
    }
    if (_containsSecretField(row)) {
      return PushValidationResult.rejected('secret_field_not_allowed');
    }
    if (table == 'messages') {
      for (final key in row.keys) {
        if (!_messagesColumns.contains(key)) {
          return PushValidationResult.rejected('column_not_allowed');
        }
      }
      if (row['content'] is! String) {
        return PushValidationResult.rejected('message_content_required');
      }
    }
    return const PushValidationResult.allowed();
  }

  bool _containsSecretField(Map<String, dynamic> row) {
    for (final key in row.keys) {
      final normalized = key.toLowerCase();
      if (_secretFields.any(normalized.contains)) return true;
    }
    return false;
  }
}
